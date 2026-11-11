pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell

import "root:/config"

Singleton {
    id: root

    // ========================================================================
    // 0. Icon Dictionaries
    // ========================================================================
    property var sun_icon_dic: ({
            395: '',
            392: '',
            389: '',
            386: '',
            377: '',
            374: '',
            371: '',
            368: '',
            365: '',
            362: '',
            359: '',
            356: '',
            353: '',
            350: '',
            338: '',
            335: '',
            332: '',
            329: '',
            326: '',
            323: '',
            320: '',
            317: '',
            314: '',
            311: '',
            308: '',
            305: '',
            302: '',
            299: '',
            296: '',
            293: '',
            284: '',
            281: '',
            266: '',
            263: '',
            260: '',
            248: '',
            230: '',
            227: '',
            200: '',
            185: '',
            182: '',
            179: '',
            176: '',
            143: '',
            122: '',
            119: '',
            116: '',
            113: ''
        })

    property var moon_icon_dic: ({
            395: '',
            392: '',
            389: '',
            386: '',
            377: '',
            374: '',
            371: '',
            368: '',
            365: '',
            362: '',
            359: '',
            356: '',
            353: '',
            350: '',
            338: '',
            335: '',
            332: '',
            329: '',
            326: '',
            323: '',
            320: '',
            317: '',
            314: '',
            311: '',
            308: '',
            305: '',
            302: '',
            299: '',
            296: '',
            293: '',
            284: '',
            281: '',
            266: '',
            263: '',
            260: '',
            248: '',
            230: '',
            227: '',
            200: '',
            185: '',
            182: '',
            179: '',
            176: '',
            143: '',
            122: '',
            119: '',
            116: '',
            113: ''
        })

    // ========================================================================
    // 1. Properties
    // ========================================================================
    property bool isLoading: true
    property string lastUpdated: ""
    property string areaName: "..."
    property string countryName: "..."
    property int currentTemp: 0
    property int feelsLike: 0
    property string weatherDescription: "Loading..."
    property string weatherCode: "113"
    property string weatherIcon: ""
    property int humidity: 0
    property int windSpeed: 0
    property string windDirection: ""
    property int pressure: 0
    property int visibility: 0
    property int uvIndex: 0
    property string sunrise: "00:00"
    property string sunset: "00:00"
    property string moonPhase: "..."
    property var dailyForecast: []
    property var hourlyForecast: []

    // Smart data
    property var aiAnalysistData: {}

    property string aiSmartIcon: ""
    property string aiEmotion: ""
    property color aiBgColor1
    property color aiBgColor2
    property color aiFgColor
    property string aiSummaryText: ""
    property string aiSmartPollingDetails: ""
    property string aiTrendBadge: ""
    property var aiTags: []
    property bool aiIsUrgent: false

    // ذاكرة المحادثة مع الـ AI — تُعاد للوراء فقط (في الذاكرة)
    // تُفقد عند إعادة تشغيل القشرة، ويُعاد بناؤها من أول تحليل
    property var _aiHistory: []

    // ========================================================================
    // 2. Signals
    // ========================================================================
    signal weatherUpdated
    signal fetchFailed(string error)

    signal chanceOfRainNotified(string message)
    signal chanceOfSnowNotified(string message)
    signal chanceOfFrostNotified(string message)
    signal chanceOfFogNotified(string message)
    signal chanceOfRemdryNotified(string message)
    signal chanceOfThunderNotified(string message)
    signal chanceOfWindyNotified(string message)
    signal chanceOfHotWeatherNotified(string message)

    signal aiAnalysisCompleted(var aiData)
    signal aiUrgentAlertReceived(string title, string message)

    // ========================================================================
    // 3. Logic
    // ========================================================================
    function getWeatherData() {
        const location = App.weather.location;
        getWeatherProcess.command = ['curl', `https://wttr.in/${location}?format=j1`];
        getWeatherProcess.running = true;
    }

    Process {
        id: getWeatherProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text;
                if (output && output.trim() !== "") {
                    root.parseWeatherData(output);
                    root.analyzeWithAI(output);
                } else {
                    isLoading = false;
                    fetchFailed("Received empty data from the server.");
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.error("Error fetching weather data:", data)
        }
    }

    // --- Helper functions for AI ---
    function analyzeWithAI(jsonString) {
        // 1. تجهيز البيانات (Data Preparation)
        try {
            const data = JSON.parse(jsonString);
            const currentTime = new Date().toLocaleTimeString(Qt.locale(), "hh:mm ap");

            if (data.current_condition && data.nearest_area && data.request && data.weather && data.weather.length > 0) {
                const filteredData = {
                    current_condition: data.current_condition,
                    nearest_area: data.nearest_area,
                    request: data.request,
                    current_time: currentTime,
                    weather: [
                        {
                            date: data.weather[0].date,
                            hourly: data.weather[0].hourly,
                            maxtempC: data.weather[0].maxtempC,
                            mintempC: data.weather[0].mintempC,
                            astronomy: data.weather[0].astronomy,
                            avgtempC: data.weather[0].avgtempC
                        }
                    ]
                };

                const message = JSON.stringify(filteredData);
                const command = App.scripts.python.callWeatherAi;

                console.info("[Weather] Sending filtered data to AI Gateway...");

                // 2. الاتصال عبر AiService
                AiService.sendRequest(command, ["--message", message], function (aiData) {
                    // aiData هو كائن نظيف تماماً الآن
                    console.info("[Weather] AI Success.");

                    // تعبئة البيانات
                    root.aiAnalysistData = aiData;
                    root.aiSmartIcon = aiData.ui?.icon || "";
                    root.aiBgColor1 = aiData.ui?.bg_color1 || null;
                    root.aiBgColor2 = aiData.ui?.bg_color2 || null;
                    root.aiFgColor = aiData.ui?.fg_color || null;

                    root.aiSummaryText = aiData.smart_summary?.summary_text || aiData.smart_summary?.arabic_text || "";
                    root.aiTrendBadge = aiData.smart_summary?.trend_badge || "";
                    root.aiTags = aiData.smart_summary?.tags || [];
                    root.aiIsUrgent = aiData.urgent_alert || false;
                    root.aiEmotion = aiData.ui?.emotion || "";

                    // إرسال الإشارات
                    root.aiAnalysisCompleted(aiData);

                    if (root.aiIsUrgent) {
                        root.aiUrgentAlertReceived(aiData.ui?.title || "تنبيه جوي", root.aiSummaryText);
                    }

                    // منطق Smart Polling (تغيير وقت التحديث القادم بناء على الطقس)
                    if (aiData.system_control && aiData.system_control.next_check_minutes) {
                        var nextMinutes = aiData.system_control.next_check_minutes;
                        root.aiSmartPollingDetails = `[Weather] Smart Polling: Next check in ${nextMinutes} minutes. Reason: ${aiData.system_control.reason}`;
                        console.info(root.aiSmartPollingDetails);

                        refreshTimer.interval = nextMinutes * 60 * 1000;
                        refreshTimer.restart();
                    }
                }, function (errorMsg) {
                    console.error("[Weather] AI Failed: " + errorMsg);
                    // في حال الفشل، نعود للتحديث الافتراضي (مثلاً كل 15 دقيقة)
                    refreshTimer.interval = 15 * 60 * 1000;
                    refreshTimer.restart();
                }, "WeatherService", 1, {
                    // Phase 5.3: credential is transported over stdin, not argv.
                    credential: App.weatherAiCredential,
                    // ذاكرة المحادثة: نُرسل التحليلات السابقة لتفادي فقدان السياق
                    history: JSON.stringify(root._aiHistory),
                    historyCap: App.weatherAiHistoryTurns,
                    onHistoryUpdated: function (newHistory) {
                        root._aiHistory = newHistory;
                    }
                });
            } else {
                console.error("Missing required weather fields for AI analysis.");
            }
        } catch (e) {
            console.error("Error preparing data for AI: " + e.message);
        }
    }

    // Parses a time string like "06:30 AM" into a comparable Date object
    function _parseTime(timeStr) {
        if (!timeStr || timeStr === "N/A")
            return null;
        const parts = timeStr.match(/(\d+):(\d+)\s*(AM|PM)/i);
        if (!parts)
            return null;

        let hours = parseInt(parts[1], 10);
        const minutes = parseInt(parts[2], 10);
        const ampm = parts[3].toUpperCase();

        if (ampm === "PM" && hours < 12)
            hours += 12;
        if (ampm === "AM" && hours === 12)
            hours = 0;

        const date = new Date();
        date.setHours(hours, minutes, 0, 0);
        return date;
    }

    // Determines if the current time is daytime
    function _isDayTime(sunriseStr, sunsetStr) {
        const now = new Date();
        const sunriseTime = _parseTime(sunriseStr);
        const sunsetTime = _parseTime(sunsetStr);

        if (!sunriseTime || !sunsetTime) {
            console.warn("Could not parse sunrise/sunset times. Defaulting to daytime.");
            return true;
        }
        return now >= sunriseTime && now < sunsetTime;
    }

    // Gets the appropriate weather icon
    function getWeatherIcon(code, isDay) {
        return isDay ? (sun_icon_dic[code] || '') : (moon_icon_dic[code] || '');
    }

    function parseWeatherData(jsonData) {
        console.info("Starting to parse weather data...");
        try {
            const data = JSON.parse(jsonData);

            const current = data?.current_condition[0];
            currentTemp = parseInt(current?.temp_C) || 0;
            feelsLike = parseInt(current?.FeelsLikeC) || 0;
            weatherDescription = current?.weatherDesc[0]?.value || "Not available";
            weatherCode = current?.weatherCode || "113";
            humidity = parseInt(current?.humidity) || 0;
            windSpeed = parseInt(current?.windspeedKmph) || 0;
            windDirection = current?.winddir16Point || "";
            pressure = parseInt(current?.pressure) || 0;
            visibility = parseInt(current?.visibility) || 0;
            uvIndex = parseInt(current?.uvIndex) || 0;

            const area = data?.nearest_area[0];
            areaName = area?.areaName[0]?.value || "Unknown location";
            countryName = area?.country[0]?.value || "";

            const astronomy = data?.weather[0]?.astronomy[0];
            sunrise = astronomy?.sunrise || "N/A";
            sunset = astronomy?.sunset || "N/A";
            moonPhase = astronomy?.moon_phase || "N/A";

            const isDay = _isDayTime(sunrise, sunset);
            weatherIcon = getWeatherIcon(weatherCode, isDay);

            let dailyData = [];
            if (data?.weather && Array.isArray(data.weather)) {
                for (let day of data.weather) {
                    const representativeHour = day?.hourly[4] || day?.hourly[0];
                    dailyData.push({
                        date: day?.date || "",
                        dayName: getDayName(day?.date),
                        minTemp: parseInt(day?.mintempC) || 0,
                        maxTemp: parseInt(day?.maxtempC) || 0,
                        avgTemp: parseInt(day?.avgtempC) || 0,
                        weatherCode: representativeHour?.weatherCode || "113",
                        description: representativeHour?.weatherDesc[0]?.value || "...",
                        icon: getWeatherIcon(representativeHour?.weatherCode || "113", true)
                    });
                }
            }
            dailyForecast = dailyData;

            let hourlyData = [];
            const todayHourly = data?.weather[0]?.hourly;
            if (todayHourly && Array.isArray(todayHourly)) {
                for (let hour of todayHourly) {
                    const timeStr = (parseInt(hour.time) / 100).toString().padStart(2, '0') + ":00";
                    hourlyData.push({
                        time: timeStr,
                        temp: parseInt(hour?.tempC) || 0,
                        weatherCode: hour?.weatherCode || "113",
                        description: hour?.weatherDesc[0]?.value || "...",
                        chanceOfRain: parseInt(hour?.chanceofrain) || 0,
                        chanceOfSnow: parseInt(hour?.chanceofsnow) || 0,
                        chanceOfFrost: parseInt(hour?.chanceoffrost) || 0,
                        chanceOfFog: parseInt(hour?.chanceoffog) || 0,
                        chanceOfRemdry: parseInt(hour?.chanceofremdry) || 0,
                        chanceOfThunder: parseInt(hour?.chanceofthunder) || 0,
                        chanceOfWindy: parseInt(hour?.chanceofwindy) || 0,
                        chanceOfHotTemp: parseInt(hour?.chanceofhightemp) || 0,
                        icon: getWeatherIcon(hour?.weatherCode || "113", _isDayTime(sunrise, sunset))
                    });
                }
            }
            hourlyForecast = hourlyData;

            checkWeatherConditions();
            lastUpdated = new Date().toLocaleTimeString([], {
                hour: '2-digit',
                minute: '2-digit'
            });
            console.log("✅ Weather data parsed successfully for:", areaName);
            isLoading = false;
            weatherUpdated();
        } catch (e) {
            isLoading = false;
            console.error("Fatal error parsing JSON data:", e.message, e.stack);
            fetchFailed("Invalid data received from the server.");
        }
    }

    function getDayName(dateString) {
        if (!dateString)
            return "";
        const date = new Date(dateString);
        const today = new Date();
        const tomorrow = new Date();
        tomorrow.setDate(today.getDate() + 1);
        if (date.toDateString() === today.toDateString())
            return "Today";
        if (date.toDateString() === tomorrow.toDateString())
            return "Tomorrow";
        return date.toLocaleDateString('en-US', {
            weekday: 'long'
        });
    }

    function checkWeatherConditions() {
        if (hourlyForecast.length === 0)
            return;

        let maxRain = 0, maxSnow = 0, maxFrost = 0, maxFog = 0;
        let maxThunder = 0, maxWindy = 0, maxHotTemp = 0;
        let minRain = 101, minSnow = 101, minFrost = 101, minFog = 101;
        let minThunder = 101, minWindy = 101, minHotTemp = 101;

        for (const hour of hourlyForecast) {
            if (hour.chanceOfRain > maxRain)
                maxRain = hour.chanceOfRain;
            if (hour.chanceOfSnow > maxSnow)
                maxSnow = hour.chanceOfSnow;
            if (hour.chanceOfFrost > maxFrost)
                maxFrost = hour.chanceOfFrost;
            if (hour.chanceOfFog > maxFog)
                maxFog = hour.chanceOfFog;
            if (hour.chanceOfThunder > maxThunder)
                maxThunder = hour.chanceOfThunder;
            if (hour.chanceOfWindy > maxWindy)
                maxWindy = hour.chanceOfWindy;
            if (hour.chanceOfHotTemp > maxHotTemp)
                maxHotTemp = hour.chanceOfHotTemp;

            if (hour.chanceOfRain < minRain)
                minRain = hour.chanceOfRain;
            if (hour.chanceOfSnow < minSnow)
                minSnow = hour.chanceOfSnow;
            if (hour.chanceOfFrost < minFrost)
                minFrost = hour.chanceOfFrost;
            if (hour.chanceOfFog < minFog)
                minFog = hour.chanceOfFog;
            if (hour.chanceOfThunder < minThunder)
                minThunder = hour.chanceOfThunder;
            if (hour.chanceOfWindy < minWindy)
                minWindy = hour.chanceOfWindy;
            if (hour.chanceOfHotTemp < minHotTemp)
                minHotTemp = hour.chanceOfHotTemp;
        }

        if (maxRain > 10)
            chanceOfRainNotified(`Min chance of rain today is ${minRain} max is ${maxRain}%`);
        if (maxSnow > 20)
            chanceOfSnowNotified(`Min chance of snow today is ${minSnow}% max is ${maxSnow}%`);
        if (maxFrost > 10)
            chanceOfFrostNotified(`Warning: Chance of frost today is between ${minFrost}% and ${maxFrost}%`);
        if (maxFog > 10)
            chanceOfFogNotified(`Warning: High chance of fog, ranging from ${minFog}% to ${maxFog}%`);
        if (maxThunder > 10)
            chanceOfThunderNotified(`Warning: Thunderstorm chance today is between ${minThunder}% and ${maxThunder}%`);
        if (maxWindy > 10)
            chanceOfWindyNotified(`It might get windy today, with chances from ${minWindy}% to ${maxWindy}%`);
        if (maxHotTemp > 10)
            chanceOfHotWeatherNotified(`Warning: High temperature expected. Chance is between ${minHotTemp}% and ${maxHotTemp}%`);
    }

    // ========================================================================
    // 4. Automation
    // ========================================================================
    Timer {
        id: refreshTimer
        interval: 900000
        running: true
        repeat: false

        onTriggered: {
            console.info("Timer triggered: Refreshing weather data...");
            getWeatherData();
        }
    }

    Component.onCompleted: {
        console.info("WeatherService started. Initial fetch...");
        getWeatherData();
    }
}
