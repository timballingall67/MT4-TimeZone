//+------------------------------------------------------------------+
//|                    TZMgt.mqh                        |
//|                    Grok, created by xAI                          |
//|                    Version 1.1, April 21, 2025                   |
//| Description: Reusable timezone management for MQL4 projects,     |
//|              handling local, broker, Sydney, London, and NY times |
//|              with accurate DST calculations.                     |
//+------------------------------------------------------------------+
#property copyright "Grok, created by xAI"
#property link      "https://x.ai"
#property strict

//+------------------------------------------------------------------+
//| Enumerations                                                    |
//+------------------------------------------------------------------+
enum VPS_Timezone {
   VPS_LONDON,    // London (GMT/BST)
   VPS_SYDNEY,    // Sydney (AEST/AEDT)
   VPS_NEWYORK,   // New York (EST/EDT)
   VPS_UTC        // UTC
};

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
input int      BrokerOffset         = 1;        // Broker time offset from UTC (1 for BST, 0 for GMT)
input VPS_Timezone SelectedVPS_Timezone = VPS_SYDNEY; // VPS timezone for TimeLocal() validation
input bool     DebugVerbose         = true;     // Enable verbose debug logging
input ENUM_TIMEFRAMES DebugTimeframe = PERIOD_M1; // Debug print timeframe (M1, M5, H1, etc.)
input bool     IgnorePCTimeMismatch  = true;     // Ignore PC time mismatch warning

// Session Times (configurable for flexibility)
input int      Sydney_StartHour     = 8;        // Sydney open hour (8 AM AEST/AEDT)
input int      Sydney_StartMinute   = 0;        // Sydney open minute
input int      Sydney_EndHour       = 17;       // Sydney close hour
input int      Sydney_EndMinute     = 0;        // Sydney close minute
input int      London_StartHour     = 8;        // London open hour (8 AM GMT/BST)
input int      London_StartMinute   = 0;        // London open minute
input int      London_EndHour       = 17;       // London close hour
input int      London_EndMinute     = 0;        // London close minute
input int      NY_StartHour         = 9;        // NY open hour (9 AM ET)
input int      NY_StartMinute       = 30;       // NY open minute (9:30 AM)
input int      NY_EndHour           = 17;       // NY close hour
input int      NY_EndMinute         = 0;        // NY close minute

//+------------------------------------------------------------------+
//| Global Variables                                                |
//+------------------------------------------------------------------+
datetime Sydney_SessionStartTime, Sydney_SessionEndTime;
datetime London_SessionStartTime, London_SessionEndTime;
datetime NY_SessionStartTime, NY_SessionEndTime;

//+------------------------------------------------------------------+
//| Function Declarations                                           |
//+------------------------------------------------------------------+
bool IsSydneyDST(datetime time);
bool IsLondonDST(datetime time);
bool IsNewYorkDST(datetime time);
datetime GetNthDayOfMonth(int year, int month, int dayOfWeek, int nth);
int GetDayOfWeek(datetime time);
int GetDaysInMonth(int year, int month);

//+------------------------------------------------------------------+
//| Initialization Function                                         |
//+------------------------------------------------------------------+
void InitTimezoneManagement()
{
   if(DebugVerbose) Print("Timezone Management Initialization - Server Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   UpdateSydneyTime();
   UpdateLondonTime();
   UpdateNYTime();
   PrintTimeInfo();
}

//+------------------------------------------------------------------+
//| Update Sydney Session Time                                      |
//+------------------------------------------------------------------+
void UpdateSydneyTime()
{
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   string timeStr = StringFormat("%02d:%02d", Sydney_StartHour, Sydney_StartMinute);
   datetime localTime = StringToTime(dateStr + " " + timeStr);
   bool isDST = IsSydneyDST(localTime);
   int offset = isDST ? 11 : 10; // AEDT (+11) or AEST (+10)
   Sydney_SessionStartTime = localTime - offset * 3600;
   
   timeStr = StringFormat("%02d:%02d", Sydney_EndHour, Sydney_EndMinute);
   Sydney_SessionEndTime = StringToTime(dateStr + " " + timeStr) - offset * 3600;
   
   if(DebugVerbose) Print("Sydney Session: ", TimeToString(localTime, TIME_DATE|TIME_MINUTES), " (Local) = ",
                         TimeToString(Sydney_SessionStartTime, TIME_DATE|TIME_MINUTES), " to ",
                         TimeToString(Sydney_SessionEndTime, TIME_DATE|TIME_MINUTES), " UTC, DST=", isDST);
}

//+------------------------------------------------------------------+
//| Update London Session Time                                      |
//+------------------------------------------------------------------+
void UpdateLondonTime()
{
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   string timeStr = StringFormat("%02d:%02d", London_StartHour, London_StartMinute);
   datetime localTime = StringToTime(dateStr + " " + timeStr);
   bool isDST = IsLondonDST(localTime);
   int offset = isDST ? 1 : 0; // BST (+1) or GMT (+0)
   London_SessionStartTime = localTime - offset * 3600;
   
   timeStr = StringFormat("%02d:%02d", London_EndHour, London_EndMinute);
   London_SessionEndTime = StringToTime(dateStr + " " + timeStr) - offset * 3600;
   
   if(DebugVerbose) Print("London Session: ", TimeToString(localTime, TIME_DATE|TIME_MINUTES), " (Local) = ",
                         TimeToString(London_SessionStartTime, TIME_DATE|TIME_MINUTES), " to ",
                         TimeToString(London_SessionEndTime, TIME_DATE|TIME_MINUTES), " UTC, DST=", isDST);
}

//+------------------------------------------------------------------+
//| Update New York Session Time                                    |
//+------------------------------------------------------------------+
void UpdateNYTime()
{
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   string timeStr = StringFormat("%02d:%02d", NY_StartHour, NY_StartMinute);
   datetime localTime = StringToTime(dateStr + " " + timeStr);
   bool isDST = IsNewYorkDST(localTime);
   int offset = isDST ? 4 : 5; // EDT (-4) or EST (-5) from UTC
   NY_SessionStartTime = localTime + offset * 3600; // Convert to UTC
   
   timeStr = StringFormat("%02d:%02d", NY_EndHour, NY_EndMinute);
   NY_SessionEndTime = StringToTime(dateStr + " " + timeStr) + offset * 3600; // Convert to UTC
   
   if(DebugVerbose) Print("NY Session: ", TimeToString(localTime, TIME_DATE|TIME_MINUTES), " (Local) = ",
                         TimeToString(NY_SessionStartTime, TIME_DATE|TIME_MINUTES), " to ",
                         TimeToString(NY_SessionEndTime, TIME_DATE|TIME_MINUTES), " UTC, DST=", isDST);
}

//+------------------------------------------------------------------+
//| Check if Sydney is in DST (AEDT)                                |
//+------------------------------------------------------------------+
bool IsSydneyDST(datetime time)
{
   MqlDateTime mdt;
   TimeToStruct(time, mdt);
   
   // Australian DST: First Sunday in October to First Sunday in April
   if(mdt.mon > 10 || mdt.mon < 4) return true;  // Oct-Mar: Summer time (DST)
   if(mdt.mon > 4 && mdt.mon < 10) return false; // May-Sep: Standard time
   
   datetime firstSundayOct = GetNthDayOfMonth(mdt.year, 10, 0, 1);
   datetime firstSundayApr = GetNthDayOfMonth(mdt.year, 4, 0, 1);
   
   if(mdt.mon == 4) return time < firstSundayApr;     // Before first Sunday in April = DST
   if(mdt.mon == 10) return time >= firstSundayOct;   // From first Sunday in October = DST
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if London is in BST                                       |
//+------------------------------------------------------------------+
bool IsLondonDST(datetime time)
{
   MqlDateTime mdt;
   TimeToStruct(time, mdt);
   
   // UK DST: Last Sunday in March to Last Sunday in October
   if(mdt.mon < 3 || mdt.mon > 10) return false;
   if(mdt.mon > 3 && mdt.mon < 10) return true;
   
   datetime lastSundayMar = GetNthDayOfMonth(mdt.year, 3, 0, -1);
   datetime lastSundayOct = GetNthDayOfMonth(mdt.year, 10, 0, -1);
   
   if(mdt.mon == 3) return time >= lastSundayMar;
   if(mdt.mon == 10) return time < lastSundayOct;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if New York is in EDT                                     |
//+------------------------------------------------------------------+
bool IsNewYorkDST(datetime time)
{
   MqlDateTime mdt;
   TimeToStruct(time, mdt);
   
   // US DST: Second Sunday in March to First Sunday in November
   if(mdt.mon < 3 || mdt.mon > 11) return false;
   if(mdt.mon > 3 && mdt.mon < 11) return true;
   
   datetime secondSundayMar = GetNthDayOfMonth(mdt.year, 3, 0, 2);
   datetime firstSundayNov = GetNthDayOfMonth(mdt.year, 11, 0, 1);
   
   if(mdt.mon == 3) return time >= secondSundayMar;
   if(mdt.mon == 11) return time < firstSundayNov;
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Day of Week (MQL4 compatible)                               |
//+------------------------------------------------------------------+
int GetDayOfWeek(datetime time)
{
   MqlDateTime mdt;
   TimeToStruct(time, mdt);
   return mdt.day_of_week;
}

//+------------------------------------------------------------------+
//| Get Days in Month                                               |
//+------------------------------------------------------------------+
int GetDaysInMonth(int year, int month)
{
   MqlDateTime mdt;
   mdt.year = year;
   mdt.mon = month;
   mdt.day = 1;
   mdt.hour = 0;
   mdt.min = 0;
   mdt.sec = 0;
   
   datetime firstOfMonth = StructToTime(mdt);
   
   // Move to next month
   mdt.mon++;
   if(mdt.mon > 12) {
      mdt.mon = 1;
      mdt.year++;
   }
   
   datetime firstOfNextMonth = StructToTime(mdt);
   int secondsInMonth = (int)(firstOfNextMonth - firstOfMonth);
   return secondsInMonth / 86400; // Convert seconds to days
}

//+------------------------------------------------------------------+
//| Find nth weekday in month                                       |
//+------------------------------------------------------------------+
datetime GetNthDayOfMonth(int year, int month, int dayOfWeek, int nth)
{
   MqlDateTime mdt;
   mdt.year = year;
   mdt.mon = month;
   mdt.day = 1;
   mdt.hour = 0;
   mdt.min = 0;
   mdt.sec = 0;
   
   datetime firstOfMonth = StructToTime(mdt);
   int firstDay = GetDayOfWeek(firstOfMonth);
   int daysToAdd = 0;
   
   if(nth > 0) {
      // Find nth occurrence (e.g., 1st Sunday, 2nd Sunday)
      daysToAdd = (dayOfWeek - firstDay + 7) % 7 + (nth - 1) * 7;
   } else {
      // Find last nth occurrence (e.g., last Sunday)
      int daysInMonth = GetDaysInMonth(year, month);
      MqlDateTime lastDayStruct;
      lastDayStruct.year = year;
      lastDayStruct.mon = month;
      lastDayStruct.day = daysInMonth;
      lastDayStruct.hour = 0;
      lastDayStruct.min = 0;
      lastDayStruct.sec = 0;
      
      datetime lastOfMonth = StructToTime(lastDayStruct);
      int lastDay = GetDayOfWeek(lastOfMonth);
      daysToAdd = daysInMonth - 1;
      daysToAdd -= (lastDay - dayOfWeek + 7) % 7;
      daysToAdd -= (-nth - 1) * 7;
   }
   
   mdt.day = 1 + daysToAdd;
   return StructToTime(mdt);
}

//+------------------------------------------------------------------+
//| Print Current Time Information with Debug                       |
//+------------------------------------------------------------------+
void PrintTimeInfo()
{
   datetime serverTime = TimeCurrent(); // Broker server time
   datetime utcTime = serverTime - BrokerOffset * 3600; // UTC time
   datetime pcTime = TimeLocal(); // PC/VPS local time
   datetime expectedLocalTime = 0;
   string vpsTimezoneName = "";
   int vpsOffsetHours = 0;
   bool isDST = false;
   
   switch(SelectedVPS_Timezone)
   {
      case VPS_LONDON:
         isDST = IsLondonDST(utcTime);
         vpsOffsetHours = isDST ? 1 : 0;
         vpsTimezoneName = isDST ? "BST" : "GMT";
         break;
      case VPS_SYDNEY:
         isDST = IsSydneyDST(utcTime);
         vpsOffsetHours = isDST ? 11 : 10;
         vpsTimezoneName = isDST ? "AEDT" : "AEST";
         break;
      case VPS_NEWYORK:
         isDST = IsNewYorkDST(utcTime);
         vpsOffsetHours = isDST ? -4 : -5;
         vpsTimezoneName = isDST ? "EDT" : "EST";
         break;
      case VPS_UTC:
         vpsOffsetHours = 0;
         vpsTimezoneName = "UTC";
         break;
   }
   
   expectedLocalTime = utcTime + vpsOffsetHours * 3600;
   double pcOffset = (pcTime - utcTime) / 3600.0;
   string pcOffsetStr = StringFormat("%.1f", pcOffset);
   
   datetime adjustedPcTime = pcTime;
   if(MathAbs(pcTime - expectedLocalTime) > 60 && !IgnorePCTimeMismatch)
   {
      Print("Warning: PC/VPS time (", TimeToString(pcTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            ") does not match expected ", vpsTimezoneName, " time (",
            TimeToString(expectedLocalTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            "). Expected offset: ", vpsOffsetHours, " hours. PC offset: ", pcOffsetStr,
            " hours. Verify VPS system clock.");
      adjustedPcTime = expectedLocalTime;
   }
   
   bool isSydneyDST = IsSydneyDST(utcTime);
   int sydneyOffset = isSydneyDST ? 11 : 10;
   datetime sydneyTime = utcTime + sydneyOffset * 3600;
   
   bool isLondonDST = IsLondonDST(utcTime);
   int londonOffset = isLondonDST ? 1 : 0;
   datetime londonTime = utcTime + londonOffset * 3600;
   
   bool isNYDST = IsNewYorkDST(utcTime);
   int nyOffset = isNYDST ? 4 : 5;
   datetime nyTime = utcTime - nyOffset * 3600;
   
   string timeframeStr = "";
   switch(DebugTimeframe)
   {
      case PERIOD_M1: timeframeStr = "1m"; break;
      case PERIOD_M5: timeframeStr = "5m"; break;
      case PERIOD_H1: timeframeStr = "1h"; break;
      case PERIOD_H4: timeframeStr = "4h"; break;
      case PERIOD_D1: timeframeStr = "1d"; break;
      default: timeframeStr = "custom"; break;
   }
   
   Print("Time Info (", timeframeStr, "): ",
         "PC=", TimeToString(adjustedPcTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), ", ",
         "Broker=", TimeToString(serverTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), ", ",
         "Sydney=", TimeToString(sydneyTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", (isSydneyDST ? "AEDT" : "AEST"), "), ",
         "London=", TimeToString(londonTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", (isLondonDST ? "BST" : "GMT"), "), ",
         "UTC=", TimeToString(utcTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), ", ",
         "NewYork=", TimeToString(nyTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS), " (", (isNYDST ? "EDT" : "EST"), ")");
}

//+------------------------------------------------------------------+
//| Usage Instructions                                              |
//+------------------------------------------------------------------+
// 1. Save as TimezoneManagement.mqh in MQL4/Include directory.
// 2. Include in your EA: #include <TimezoneManagement.mqh>
// 3. Initialize in OnInit(): InitTimezoneManagement();
// 4. Update times in OnTick() or as needed: UpdateSydneyTime(), UpdateLondonTime(), UpdateNYTime();
// 5. Access global variables: Sydney_SessionStartTime, London_SessionStartTime, NY_SessionStartTime, etc.
// 6. Use PrintTimeInfo() for debugging time calculations.
// 7. Configure inputs (BrokerOffset, SelectedVPS_Timezone, session times) as needed.
//+------------------------------------------------------------------+