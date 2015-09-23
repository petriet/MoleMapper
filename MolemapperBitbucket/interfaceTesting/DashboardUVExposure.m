//
//  DashboardUVExposure.m
//  MoleMapper
//
//  Created by Karpács István on 21/09/15.
//  Copyright © 2015 Webster Apps. All rights reserved.
//

#import "DashboardUVExposure.h"
#import "DashboardModel.h"

@implementation DashboardUVExposure


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self getUVJsonDataByZipCode];
    // Configure the view for the selected state
}

-(void) getUVJsonDataByZipCode
{
    // Prepare the link that is going to be used on the GET request
    NSURL * url = [[NSURL alloc] initWithString:@"http://iaspub.epa.gov/enviro/efservice/getEnvirofactsUVHOURLY/ZIP/20902/JSON"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];

    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               _jsonUVIndexDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                                        options:0
                                                                                          error:nil];
                               [self setupChartView];
                               NSLog(@"Async JSON: %@", _jsonUVIndexDictionary);
                           }];
}

-(void)setupChartView
{
    _header.backgroundColor = [[DashboardModel sharedInstance] getColorForHeader];
    _headerTitle.textColor = [[DashboardModel sharedInstance] getColorForDashboardTextAndButtons];
    
    _chartView.descriptionText = @"";
    _chartView.noDataTextDescription = @"You need to provide data for the chart.";
    
    _chartView.dragEnabled = NO;
    [_chartView setScaleEnabled:NO];
    _chartView.pinchZoomEnabled = NO;
    _chartView.drawGridBackgroundEnabled = NO;
    
    ChartYAxis *leftAxis = _chartView.leftAxis;
    [leftAxis removeAllLimitLines];
    leftAxis.customAxisMax = [self getHighestUVValueFromJson] - 0.1f;
    leftAxis.customAxisMin = 0;
    leftAxis.startAtZeroEnabled = NO;
    leftAxis.gridLineDashLengths = @[@1.f, @1.f];
    leftAxis.drawLimitLinesBehindDataEnabled = YES;
    leftAxis.gridColor = [UIColor blackColor];
    
    ChartXAxis *xAxis = _chartView.xAxis;
    xAxis.labelPosition = XAxisLabelPositionBottom;
    xAxis.labelFont = [UIFont systemFontOfSize:8.f];
    xAxis.drawGridLinesEnabled = YES;
    xAxis.spaceBetweenLabels = 2.0;
    
    _chartView.rightAxis.enabled = NO;

    
    [self setDataCount];
    [_chartView animateWithXAxisDuration:0.0 yAxisDuration:3.0];
}

- (void)setDataCount
{
    NSMutableArray *xVals = [[NSMutableArray alloc] init];
    //int startPos = [self chartStartPos];
    
    int startPos = [self getStartOrderPostion];
    
    for (int i = startPos; i < startPos + 7; i++)
    {
        NSString* dateTime = [[_jsonUVIndexDictionary objectAtIndex:i] objectForKey:@"DATE_TIME"];
        NSArray* dateTimeArray = [dateTime componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
        NSString* hourString = [dateTimeArray objectAtIndex:1];
        NSString* firstChar = [hourString substringToIndex:1];
        NSString* correctHourString = [firstChar isEqualToString:@"0"] ? [hourString componentsSeparatedByString:@"0"][1] : hourString;
        NSString* xDataLabel = [NSString stringWithFormat:@"%@ %@", correctHourString, [dateTimeArray objectAtIndex:2]];
        [xVals addObject:xDataLabel];
    }
    
    NSMutableArray *yVals = [[NSMutableArray alloc] init];
    NSMutableArray *yVals2 = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < 8; i++)
    {
        int val = (int)[self getUVBasedIndex:i + startPos];
        [yVals addObject:[[ChartDataEntry alloc] initWithValue:val xIndex:i]];
        [yVals2 addObject:[[ChartDataEntry alloc] initWithValue:0 xIndex:i]];
    }
    
    LineChartDataSet *set1 = [[LineChartDataSet alloc] initWithYVals:yVals label:@""];
    LineChartDataSet *set2 = [[LineChartDataSet alloc] initWithYVals:yVals2 label:@""];
    
    set1.lineDashLengths = @[@1.f, @1.0f];
    [set1 setColor:UIColor.whiteColor];
    [set1 setCircleColor:[[DashboardModel sharedInstance] getColorForDashboardTextAndButtons]];
    set1.lineWidth = 0.0;
    set1.circleRadius = 3.0;
    set1.drawCircleHoleEnabled = YES;
    set1.valueFont = [UIFont systemFontOfSize:9.f];
    set1.fillAlpha = 255/255.0;
    set1.fillColor = UIColor.blackColor;
    
    NSMutableArray *dataSets = [[NSMutableArray alloc] init];
    [dataSets addObject:set1];
    
    set2.lineDashLengths = @[@0.f, @0.0f];
    [set2 setColor:UIColor.whiteColor];
    [set2 setCircleColor:[[DashboardModel sharedInstance] getColorForDashboardTextAndButtons]];
    set2.lineWidth = 0.0;
    set2.circleRadius = 3.0;
    set2.drawCircleHoleEnabled = YES;
    set2.valueFont = [UIFont systemFontOfSize:0.f];
    set2.fillAlpha = 255/255.0;
    set2.fillColor = UIColor.blackColor;
    
    NSMutableArray *dataSets2 = [[NSMutableArray alloc] init];
    [dataSets addObject:set2];
    
    LineChartData *data = [[LineChartData alloc] initWithXVals:xVals dataSets:dataSets];
    LineChartData *data2 = [[LineChartData alloc] initWithXVals:xVals dataSets:dataSets2];
    
    _chartView.data = data;
    _chartView.data = data2;
}

-(int) getUVBasedIndex: (int) idx
{
    NSDictionary* currentUvData = [_jsonUVIndexDictionary objectAtIndex:idx];
    NSNumber* currectUv = [currentUvData objectForKey:@"UV_VALUE"];
    return (int)[currectUv integerValue];
}

-(int) getHighestUVValueFromJson
{
    int highestUV = 0;
    for (int i = 0; i < (int)[_jsonUVIndexDictionary count]; ++i)
    {
        int currentUv = [self getUVBasedIndex: i];
        highestUV = currentUv > highestUV ? currentUv : highestUV;
    }
    
    return highestUV + 1;
}

-(int) getStartOrderPostion
{
    for (int i = 0; i < (int)[_jsonUVIndexDictionary count]; ++i)
    {
        int x = [self orderPosition:i];
        if (x != -1) return x;
    }
    
    return nil;
}

-(int) orderPosition : (int) idx
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:[NSDate date]];
    NSInteger currentHour = [components hour];
    
    NSDictionary* currentUvData = [_jsonUVIndexDictionary objectAtIndex:idx];
    NSString* dateTime = [currentUvData objectForKey:@"DATE_TIME"];
    NSArray* dateTimeArray = [dateTime componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    NSString* hourString = [dateTimeArray objectAtIndex:1];
    NSString* firstChar = [hourString substringToIndex:1];
    NSString* correctHourString = [firstChar isEqualToString:@"0"] ? [hourString componentsSeparatedByString:@"0"][1] : hourString;
    int hourInt = [[correctHourString stringByTrimmingCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] intValue];
    
    if ([[dateTimeArray objectAtIndex:2] isEqualToString:@"AM"])
    {
        if (hourInt == (int)currentHour)
            return [self getFirstOrderPosition:(int)currentHour: hourInt withDictionary:currentUvData];
    }
    
    if ([[dateTimeArray objectAtIndex:2] isEqualToString:@"PM"])
    {
        if (hourInt == (int)currentHour - 12)
            return [self getFirstOrderPosition:(int)currentHour - 12: hourInt withDictionary:currentUvData];
    }
    
    return -1;
}

- (int) getFirstOrderPosition: (int) currentHour : (int) hourInt withDictionary: (NSDictionary*) currentUvData
{
    int dataRate = 7;
    
    int order = [currentUvData objectForKey:@"ORDER"];
    
    if (order - dataRate >= 1 && order + dataRate < [_jsonUVIndexDictionary count])
    {
        return (order - dataRate) - 1;
    }
    else if (order - dataRate < 1)
    {
        return 0;
    }
    else if (order + dataRate >= [_jsonUVIndexDictionary count])
    {
        return ((int)[_jsonUVIndexDictionary count] - dataRate) - 1;
    }
    
    return nil;
}


@end
