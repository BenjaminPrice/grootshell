pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The forecast, from Open-Meteo.
//
// Chosen because it needs no API key. Every other free provider wants a
// registration before it will tell you the temperature, and a shell that asks
// each person who clones it to sign up for something is a shell nobody else
// runs. This is the one piece of the repo where the choice of upstream is really
// a choice about who can use it.
//
// Two requests, not one. A place name has to become coordinates first, so the
// geocoding endpoint runs once per location change and the forecast endpoint
// runs on a timer against the result. Caching the coordinates rather than
// re-geocoding every quarter of an hour is the whole reason they are separate.
//
// XMLHttpRequest rather than shelling out to curl, which is what
// modules/translate uses. That was a considered exception — Google's endpoint
// serves a bot page to Qt's user agent — and it does not apply to a plain JSON
// API. Not spawning a process per poll also means one less thing a non-Nix user
// has to have installed.

Singleton {
    id: root

    // --- Configuration ------------------------------------------------------
    readonly property string location: Config.weather.location
    readonly property bool imperial: Config.weather.units === "imperial"
    readonly property bool configured: root.location.trim() !== ""

    readonly property string tempUnit: root.imperial ? "°F" : "°C"
    readonly property string windUnit: root.imperial ? "mph" : "km/h"
    readonly property string precipUnit: root.imperial ? "in" : "mm"

    // --- Resolved place -----------------------------------------------------
    property real latitude: 0
    property real longitude: 0
    property string place: ""
    property bool located: false

    // --- Data ---------------------------------------------------------------
    // `current` is null until the first successful fetch. Everything that draws
    // it must cope with that: the panel is opened long before the network
    // answers, and on a cold start it may never answer at all.
    property var current: null
    property var hourly: []
    property var daily: []

    property bool loading: false
    // Empty when things are fine. Shown verbatim in the tab, so it has to read
    // as a sentence rather than as a status code.
    property string error: ""

    // --- WMO weather codes --------------------------------------------------
    //
    // Open-Meteo reports WMO 4677, which is a standard with far more precision
    // than a glyph can carry — "slight" and "moderate" drizzle get their own
    // numbers. These collapse to the distinctions a person actually makes when
    // deciding whether to take a coat.
    //
    // Day and night differ only for the clear and partly-clouded codes. Rain at
    // night is still rain, and Material Symbols has no separate glyph for it.
    function icon(code: int, isDay: bool): string {
        switch (code) {
        case 0:
            return isDay ? "clear_day" : "clear_night";
        case 1:
        case 2:
            return isDay ? "partly_cloudy_day" : "partly_cloudy_night";
        case 3:
            return "cloud";
        case 45:
        case 48:
            return "foggy";
        case 51:
        case 53:
        case 55:
        case 56:
        case 57:
        case 61:
        case 63:
        case 65:
        case 66:
        case 67:
        case 80:
        case 81:
        case 82:
            return "rainy";
        case 71:
        case 73:
        case 75:
        case 77:
        case 85:
        case 86:
            return "weather_snowy";
        case 95:
        case 96:
        case 99:
            return "thunderstorm";
        }
        return "cloud";
    }

    function describe(code: int): string {
        switch (code) {
        case 0:
            return "Clear";
        case 1:
            return "Mainly clear";
        case 2:
            return "Partly cloudy";
        case 3:
            return "Overcast";
        case 45:
            return "Fog";
        case 48:
            return "Freezing fog";
        case 51:
            return "Light drizzle";
        case 53:
            return "Drizzle";
        case 55:
            return "Heavy drizzle";
        case 56:
        case 57:
            return "Freezing drizzle";
        case 61:
            return "Light rain";
        case 63:
            return "Rain";
        case 65:
            return "Heavy rain";
        case 66:
        case 67:
            return "Freezing rain";
        case 71:
            return "Light snow";
        case 73:
            return "Snow";
        case 75:
            return "Heavy snow";
        case 77:
            return "Snow grains";
        case 80:
            return "Light showers";
        case 81:
            return "Showers";
        case 82:
            return "Heavy showers";
        case 85:
            return "Light snow showers";
        case 86:
            return "Snow showers";
        case 95:
            return "Thunderstorm";
        case 96:
        case 99:
            return "Thunderstorm with hail";
        }
        return "Unknown";
    }

    // Rounded for display everywhere. A forecast that claims a tenth of a degree
    // ten days out is asserting a precision it does not have.
    function temp(value: real): string {
        return `${Math.round(value)}°`;
    }

    // --- Fetching -----------------------------------------------------------

    function get(url: string, onDone: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                root.loading = false;
                // status 0 is the shape a DNS failure or a dropped connection
                // takes here, and "the weather service returned 0" would send
                // someone looking in the wrong place entirely.
                root.error = xhr.status === 0 ? "Could not reach the weather service" : `Weather service returned ${xhr.status}`;
                return;
            }
            try {
                onDone(JSON.parse(xhr.responseText));
            } catch (e) {
                root.loading = false;
                root.error = "The weather service sent something unreadable";
                console.warn("grootshell: weather parse failed:", e);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function locate(): void {
        if (!root.configured) {
            root.located = false;
            root.error = "";
            return;
        }
        root.loading = true;
        root.error = "";
        root.get(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(root.location.trim())}&count=1&language=en&format=json`, data => {
            const hit = (data.results ?? [])[0];
            if (!hit) {
                root.loading = false;
                root.located = false;
                root.error = `Nowhere called “${root.location}” was found`;
                return;
            }
            root.latitude = hit.latitude;
            root.longitude = hit.longitude;
            // Qualified with the country so two places of the same name are
            // distinguishable — which is exactly when you want to know that the
            // geocoder picked the other one.
            root.place = hit.country ? `${hit.name}, ${hit.country}` : hit.name;
            root.located = true;
            root.fetch();
        });
    }

    function fetch(): void {
        if (!root.located)
            return;
        root.loading = true;

        const units = root.imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch" : "";

        // timezone=auto so the daily buckets and the sunrise times are the
        // FORECAST location's local days, not this machine's. Asking about a
        // city eight hours away and being told about our midnight would put the
        // wrong weather under every heading.
        const url = `https://api.open-meteo.com/v1/forecast?latitude=${root.latitude}&longitude=${root.longitude}` + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,is_day" + "&hourly=temperature_2m,weather_code,precipitation_probability" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset" + `&timezone=auto&forecast_days=${Math.max(1, Math.min(16, Config.weather.days))}` + units;

        root.get(url, data => {
            root.loading = false;
            root.error = "";

            const c = data.current ?? {};
            root.current = {
                temperature: c.temperature_2m ?? 0,
                apparent: c.apparent_temperature ?? 0,
                humidity: c.relative_humidity_2m ?? 0,
                precipitation: c.precipitation ?? 0,
                code: c.weather_code ?? 0,
                wind: c.wind_speed_10m ?? 0,
                isDay: (c.is_day ?? 1) === 1
            };

            // Zipped into objects here rather than left as parallel arrays. The
            // API returns column-major — one array per field — and every
            // consumer would otherwise have to index four arrays in step and
            // stay correct while doing it.
            const h = data.hourly ?? {};
            const hours = [];
            const times = h.time ?? [];
            for (let i = 0; i < times.length; i++) {
                hours.push({
                    at: Date.parse(times[i]),
                    temperature: (h.temperature_2m ?? [])[i] ?? 0,
                    code: (h.weather_code ?? [])[i] ?? 0,
                    precipitation: (h.precipitation_probability ?? [])[i] ?? 0
                });
            }
            root.hourly = hours;

            const d = data.daily ?? {};
            const days = [];
            const dates = d.time ?? [];
            for (let i = 0; i < dates.length; i++) {
                days.push({
                    // "T00:00" appended deliberately. A bare "2026-08-29" is
                    // parsed as UTC midnight by specification, where the hourly
                    // strings — which carry a time — are parsed as local. Left
                    // alone, the two disagree by the UTC offset, and anywhere
                    // west of Greenwich every daily row would be labelled with
                    // the previous day.
                    //
                    // These are the forecast location's local times, because the
                    // request asks for timezone=auto. Reading them as this
                    // machine's local time is exact for your own city and drifts
                    // by the offset for somewhere else, which is the right trade
                    // for the common case.
                    at: Date.parse(dates[i] + "T00:00"),
                    code: (d.weather_code ?? [])[i] ?? 0,
                    max: (d.temperature_2m_max ?? [])[i] ?? 0,
                    min: (d.temperature_2m_min ?? [])[i] ?? 0,
                    precipitation: (d.precipitation_probability_max ?? [])[i] ?? 0,
                    sunrise: Date.parse((d.sunrise ?? [])[i] ?? ""),
                    sunset: Date.parse((d.sunset ?? [])[i] ?? "")
                });
            }
            root.daily = days;
        });
    }

    // The hours from now onward, which is the only part of an hourly forecast
    // anyone wants. The API returns whole local days including ones already
    // spent.
    function upcomingHours(count: int): var {
        const now = Date.now() - 3600000; // keep the hour in progress
        const out = [];
        for (let i = 0; i < root.hourly.length && out.length < count; i++) {
            if (root.hourly[i].at >= now)
                out.push(root.hourly[i]);
        }
        return out;
    }

    // Re-geocode when the place changes, refetch when the units do — the API
    // does the conversion, so different units are a different request.
    onLocationChanged: root.locate()
    onImperialChanged: root.fetch()

    Component.onCompleted: root.locate()

    Timer {
        interval: Math.max(1, Config.weather.updateMinutes) * 60000
        repeat: true
        running: root.located
        onTriggered: root.fetch()
    }
}
