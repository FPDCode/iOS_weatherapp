import SwiftUI
import WidgetKit

@main
struct WeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        RainActivityLiveActivity()
        CurrentConditionsWidget()
        HourlyForecastWidget()
        RainTimelineWidget()
        DailyForecastWidget()
        BestTimeForWidget()
    }
}
