// SPDX-FileCopyrightText: 2026 Sailfish contributors
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.6
import Nemo.Configuration 1.0
import "BackendUtils.js" as BackendUtils
import "WeatherTypeDescriptions.js" as WeatherTypeDescriptions

QtObject {

    function providerId() {
        return "caiyun"
    }
    readonly property ConfigurationValue providerAppKey: ConfigurationValue {
        key: "/sailfish/weather/" + providerId() + "_app_id"
        defaultValue: ""
    }

    readonly property string caiyunApiBase: "https://api.caiyunapp.com/v2.6/" + providerAppKey.value

    function providerTitle() {
        return "彩云天气"
    }

    function requiresApiKey() {
        return true
    }

    function apiKeyInstructions() {
        return "如何获取 API Key:"
               + "<ol><li>打开<b><a href='https://platform.caiyunapp.com/'>彩云天气开放平台</a></b> 并注册一个开发者账号。</li>"
               + "<li>可能需要认证，姓名不需要填真实的。</li>"
               + "<li>创建一个应用，类型选<b>天气</b>，应用场景选<b>其他</b>，点击新建。</li>"
               + "<li>此时应该会有一个token，复制它，贴到这里。</li></ol>"
    }

    function attributionText() {
        return "天气数据来自<a href='https://www.caiyunapp.com/'>彩云天气</a>."
    }

    function shortAttributionText() {
        return "天气数据来自彩云天气"
    }

    function fetchToken(weatherRequest, apiKey) {
        weatherRequest.token = ""
        return true
    }

    function requestHeaders() {
        return {
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
        }
    }

    function currentWeatherUrl(weather) {
        return caiyunApiBase + "/" + weather.longitude + "," + weather.latitude + "/realtime"
    }

    function latestObservationUrl(weather) {
        return currentWeatherUrl(weather)
    }

    function forecastUrl(weather, isHourly) {
        if (isHourly) {
            return caiyunApiBase + "/" + weather.longitude + "," + weather.latitude + "/hourly?hourlysteps=24"
        } else {
            return caiyunApiBase + "/" + weather.longitude + "," + weather.latitude + "/daily?dailysteps=7"
        }
    }

    function searchLocationUrl(filter, language) {
        return "https://fog-umbrella.cyapi.cn/amap/v3/place/text?keywords=" + encodeURIComponent(filter)
    }

    function handleCurrentWeatherResult(result) {
        if (!result || result.status !== "ok" || !result.result || !result.result.realtime) {
            return undefined
        }

        var realtime = result.result.realtime
        var skycon = realtime.skycon || "CLEAR_DAY"
        var cloudrate = realtime.cloudrate !== undefined ? Math.round(realtime.cloudrate * 100) : undefined
        var isDay = (skycon.indexOf("_DAY") !== -1) ? 1 : 0

        var weather = getWeatherData(skycon, cloudrate, isDay)
        weather.timestamp = new Date(result.server_time * 1000)
        weather.temperature = realtime.temperature
        weather.feelsLikeTemperature = realtime.apparent_temperature !== undefined ? realtime.apparent_temperature : realtime.temperature
        weather.latitude = weather.latitude || result.location[0]
        weather.longitude = result.location[1]

        if (realtime.wind) {
            weather.windDirection = realtime.wind.direction
            weather.maximumWindSpeed = Math.round(realtime.wind.speed)
        }

        if (realtime.humidity !== undefined) {
            weather.humidity = Math.round(realtime.humidity * 100)
        }

        return weather
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        if (!result || result.status !== "ok") {
            return undefined
        }

        return hourly ? handleHourlyForecastResult(result, visibleCount, minimumHourlyRange)
                      : handleDailyForecastResult(result)
    }

    function handleHourlyForecastResult(result, visibleCount, minimumHourlyRange) {
        var hourly = result.result.hourly
        if (!hourly || !hourly.temperature || hourly.temperature.length === 0) {
            return undefined
        }

        var weatherData = []
        for (var i = 0; i < hourly.temperature.length && weatherData.length < visibleCount + 1; i++) {
            var tempData = hourly.temperature[i]
            var skyconData = hourly.skycon ? hourly.skycon[i] : null
            var cloudData = hourly.cloudrate ? hourly.cloudrate[i] : null
            var precipData = hourly.precipitation ? hourly.precipitation[i] : null
            var windData = hourly.wind ? hourly.wind[i] : null

            if (!tempData || tempData.value === undefined) {
                continue
            }

            var skycon = skyconData ? skyconData.value : "CLEAR_DAY"
            var cloudrate = cloudData && cloudData.value !== undefined ? Math.round(cloudData.value * 100) : undefined
            var isDay = (skycon.indexOf("_DAY") !== -1) ? 1 : 0

            var weather = getWeatherData(skycon, cloudrate, isDay)
            var datetime = new Date(tempData.datetime)
            weather.timestamp = datetime
            weather.temperature = tempData.value

            if (hourly.apparent_temperature && hourly.apparent_temperature[i]) {
                weather.feelsLikeTemperature = hourly.apparent_temperature[i].value
            }

            if (windData) {
                weather.windDirection = windData.direction
                weather.maximumWindSpeed = Math.round(windData.speed)
            }

            if (precipData) {
                weather.accumulatedPrecipitation = precipData.value
                weather.precipitationProbability = precipData.probability
            }

            weatherData[weatherData.length] = weather
        }

        return BackendUtils.normalizeHourlyTemperatures(
                    weatherData, visibleCount, minimumHourlyRange, true)
    }

    function handleDailyForecastResult(result) {
        var daily = result.result.daily
        if (!daily || !daily.temperature || daily.temperature.length === 0) {
            return undefined
        }

        var weatherData = []
        var maxDays = 7
        for (var i = 0; i < maxDays && i < daily.temperature.length; i++) {
            var tempData = daily.temperature[i]
            var skyconData = daily.skycon ? daily.skycon[i] : null
            var cloudData = daily.cloudrate ? daily.cloudrate[i] : null
            var precipData = daily.precipitation ? daily.precipitation[i] : null
            var windData = daily.wind ? daily.wind[i] : null

            if (!tempData || tempData.max === undefined || tempData.min === undefined) {
                continue
            }

            var skycon = skyconData ? skyconData.value : "CLEAR_DAY"
            var cloudrate = cloudData && cloudData.avg !== undefined ? Math.round(cloudData.avg * 100) : undefined
            var isDay = (skycon.indexOf("_DAY") !== -1) ? 1 : 0

            var weather = getWeatherData(skycon, cloudrate, isDay)
            weather.timestamp = new Date(tempData.date)
            weather.high = Math.floor(tempData.max)
            weather.low = Math.round(tempData.min)

            if (precipData) {
                weather.accumulatedPrecipitation = precipData.avg !== undefined ? precipData.avg : 0
            } else {
                weather.accumulatedPrecipitation = 0
            }

            if (windData && windData.max) {
                weather.maximumWindSpeed = Math.round(windData.max.speed)
                weather.windDirection = windData.max.direction
            }

            weatherData[weatherData.length] = weather
        }

        return weatherData.length > 0 ? weatherData : undefined
    }

    function handleSearchLocationResult(result) {
        if (!result) {
            return undefined
        }

        var locations = []
        var results = result.results || result.pois
        if (!results || results.length === 0) {
            return []
        }

        for (var i = 0; i < results.length; i++) {
            var location = results[i]
            var lat, lon

            if (location.latitude !== undefined && location.longitude !== undefined) {
                lat = parseFloat(location.latitude)
                lon = parseFloat(location.longitude)
            } else if (location.location) {
                var coords = location.location.split(",")
                if (coords.length === 2) {
                    lon = parseFloat(coords[0])
                    lat = parseFloat(coords[1])
                }
            }

            if (isNaN(lat) || isNaN(lon)) {
                continue
            }

            var locationId = parseInt(location.id, 10)
            if (!isFinite(locationId) || locationId <= 0) {
                locationId = hashLatLon(lat, lon, 15, 0x43415955)
            }

            var admin1 = location.admin1 || location.pname || ""
            var admin2 = location.admin2 || location.cityname || ""
            var admin3 = location.admin3 || ""
            var admin4 = location.admin4 || ""

            locations[locations.length] = {
                "id": locationId,
                "name": location.name || "",
                "state": admin1,
                "country": location.country || location.adname || "",
                "adminArea": admin1,
                "adminArea2": admin2 || admin3 || admin4,
                "latitude": lat,
                "longitude": lon
            }
        }

        return locations.length > 0 ? locations : undefined
    }

    function handleObservationResult(result) {
        return ""
    }

    function externalUrl(weather) {
        return "https://github.com/0312birdzhang/sailfish-weather-backend-caiyun"
    }

    function providerImage() {
        return "image://theme/caiyun?"
    }

    function smallProviderImage() {
        return "image://theme/caiyun-small?"
    }

    function getWeatherData(skycon, cloudiness, isDay) {
        var weatherTypeCode = weatherTypeFromCaiyunSkycon(skycon, cloudiness)
        var timePrefix = isDay === 0 ? "n" : "d"
        return {
            "description": WeatherTypeDescriptions.description(timePrefix + weatherTypeCode),
            "weatherType": weatherType(timePrefix + weatherTypeCode),
            "cloudiness": cloudiness !== undefined ? cloudiness : cloudinessFromCaiyunSkycon(skycon)
        }
    }

    function weatherTypeFromCaiyunSkycon(skycon, cloudiness) {
        switch (skycon) {
        case "CLEAR_DAY":
            return "000"
        case "CLEAR_NIGHT":
            return "000"
        case "PARTLY_CLOUDY_DAY":
            return cloudVariant(cloudiness, "100", "200", "300")
        case "PARTLY_CLOUDY_NIGHT":
            return cloudVariant(cloudiness, "100", "200", "300")
        case "CLOUDY":
            return "400"
        case "LIGHT_HAZE":
        case "MODERATE_HAZE":
        case "HEAVY_HAZE":
            return cloudVariant(cloudiness, "500", "500", "500")
        case "LIGHT_RAIN":
            return cloudVariant(cloudiness, "210", "310", "410")
        case "MODERATE_RAIN":
            return cloudVariant(cloudiness, "220", "320", "420")
        case "HEAVY_RAIN":
            return cloudVariant(cloudiness, "220", "320", "430")
        case "STORM_RAIN":
            return cloudVariant(cloudiness, "240", "340", "440")
        case "FOG":
            return "600"
        case "LIGHT_SNOW":
            return cloudVariant(cloudiness, "212", "312", "412")
        case "MODERATE_SNOW":
            return cloudVariant(cloudiness, "222", "322", "422")
        case "HEAVY_SNOW":
            return cloudVariant(cloudiness, "222", "322", "432")
        case "STORM_SNOW":
            return cloudVariant(cloudiness, "240", "340", "440")
        case "DUST":
        case "SAND":
            return "610"
        case "WIND":
            return cloudVariant(cloudiness, "100", "200", "400")
        default:
            return cloudinessCode(cloudiness)
        }
    }

    function cloudinessFromCaiyunSkycon(skycon) {
        switch (skycon) {
        case "CLEAR_DAY":
        case "CLEAR_NIGHT":
            return 0
        case "PARTLY_CLOUDY_DAY":
        case "PARTLY_CLOUDY_NIGHT":
            return 50
        case "CLOUDY":
            return 100
        case "FOG":
        case "LIGHT_HAZE":
        case "MODERATE_HAZE":
        case "HEAVY_HAZE":
        case "DUST":
        case "SAND":
            return 100
        default:
            return 100
        }
    }

    function cloudVariant(cloudiness, partlyCloudyCode, cloudyCode, overcastCode) {
        if (cloudiness === undefined || cloudiness === null) {
            return overcastCode
        }
        if (cloudiness < 30) {
            return partlyCloudyCode
        }
        if (cloudiness < 70) {
            return cloudyCode
        }
        return overcastCode
    }

    function cloudinessCode(cloudiness) {
        if (cloudiness === undefined || cloudiness === null) {
            return "400"
        }
        if (cloudiness < 20) {
            return "000"
        }
        if (cloudiness < 45) {
            return "100"
        }
        if (cloudiness < 75) {
            return "200"
        }
        if (cloudiness < 95) {
            return "300"
        }
        return "400"
    }

    function weatherType(code) {
        if (code.length === 4) {
            return code
        }

        console.warn("Invalid weather code")
        return ""
    }

    function hashLatLon(lat, lon, precisionBits, seed) {
        precisionBits = precisionBits || 16
        seed = seed || 0

        var latScaled = Math.floor(((lat + 90) / 180) * (1 << precisionBits))
        var lonScaled = Math.floor(((lon + 180) / 360) * (1 << precisionBits))
        var hash = ((latScaled << precisionBits) | lonScaled) ^ seed
        hash = hash & 0x7fffffff
        return hash > 0 ? hash : 1
    }
}
