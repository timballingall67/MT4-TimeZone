// Vibe coded ( GRok & Deepseek ) header to allow TZ management across Sydney, New York and London Sessions.
// Includes DST calculations
// NOT FULLY TESTED - USE AT YOUR OWN RISK
// NO WARRANTY GIVEN OR IMPLIED
//+------------------------------------------------------------------+
//| Usage Instructions                                              |
//+------------------------------------------------------------------+
// 1. Save as TZMgt.mqh in MQL4/Include directory.
// 2. Include in your EA: #include <TZMgt.mqh>
// 3. Initialize in OnInit(): InitTimezoneManagement();
// 4. Update times in OnTick() or as needed: UpdateSydneyTime(), UpdateLondonTime(), UpdateNYTime();
// 5. Access global variables: Sydney_SessionStartTime, London_SessionStartTime, NY_SessionStartTime, etc.
// 6. Use PrintTimeInfo() for debugging time calculations.
// 7. Configure inputs (BrokerOffset, SelectedVPS_Timezone, session times) as needed.
//+------------------------------------------------------------------+
