//TO DO: sprawdzenie BodyTransposition i dodanie do niego inputa !
// raz dwa test




#include<Trade\Trade.mqh>
CTrade trade;
static MqlRates PriceInformation[];                        //create a price array
static int candleCounter;
static datetime timeStampLastCheck;
static double CandleTrendPercentage;
static int CandleDirection;
static double CandleCoveredPart;
static double CandleHeight;
static double CandleCoveredPercentage;
static int TempFlagOrdersCount = 0; //jeśli TempFlagOrdersCount będzie większe niż liczba wykonanych zleceń, tzn. że jakieś BuyLimit lub SellLimit się wykonało ale bez stworzenia zlecenia
static int FlagSignal = 0;     //jeśli 1 to poprzedzająca świeca jest świecą sygnalną
static int ThisCandleOpenOrders = 0; //jeśli 1 to na bierzącej świecy zostało już otwarte zlecenie
static int TempFlagOpenOrderEnter = 0;
input double InputTrendCandle;
input double InputCandlesMaxCoveredPartPercentage;
input int InputTicksToOpen;
input int InputTicksToClose;
input bool TurnOnSignalConditionsDisplay = true;
static int errors = 0;
static int TextObjectIncrement = 0;
static string TextObjectName;
static int HighestOrLowest; //just for Displaying which candle from last 10 is lowest/highest

void OnInit() {
   Comment("TrendCandle%: "+InputTrendCandle+
           "\nMaxCoverage%: "+InputCandlesMaxCoveredPartPercentage+
           "\nOpenNearCloseTicks: "+"."+
           "\nBodyTransposition: "+".");
}

void OnTick() {
   ArraySetAsSeries(PriceInformation,true);
   CopyRates(_Symbol,_Period,0,3,PriceInformation);   //copy candle prices for 3 candles into array (ewentualnie można wciepać funkcję Bars zamiast 3)
   
   datetime timeStampCurrentCandle = PriceInformation[0].time; //sprawdź jaki czas ma current candle (PORÓWNUJE Z NULLEM ZA PIERWSYM RAZEM)
   
   if(FlagSignal==1 && ThisCandleOpenOrders==0)    //pytanie do WOJTIEGO: czy taki podwójny if poprawia mi złożoność
      //if(SignalToOpen())         // TO CHYBA NIEPOTRZEBNE SKORO POPRZEDNIA ŚWIECA JEST SYGNALNA
         OpenOrder();  
   
   
   if(timeStampCurrentCandle != timeStampLastCheck) { //jeśli pojawia się nowa świeca
      CopyRates(_Symbol,_Period,0,20,PriceInformation); //będziemy sprwadać warunki więc potrzebujemy info o większej liczbie świec
      timeStampLastCheck=timeStampCurrentCandle;   //updatujemy sprawdzacza
      ThisCandleOpenOrders=0;       //na tej świecy nie zawarło się jeszcze żadne zlecenie
      FlagSignal=0;     //jeszcze nie wiem czy nowa świeca jest poprzedzana przez świecę sygnalną
      //candleCounter+=1;
      //if (PriceInformation[1].close > PriceInformation[2].close) Comment("It is going up");
      SetCandleDirection();

      if(SignalToOpen()) {
         FlagSignal=1;
         OpenOrder();
      }
   if(TurnOnSignalConditionsDisplay) SignalConditionsDisplay();
   }
   //Comment("Counted candles since start: ",candleCounter);
   ViewControlInfo();
}

bool SignalToOpen() {
   bool cond1=false, cond2=false, cond3=false, cond4=false; //chcemy aby został wykonany każdy warunek, z których składa się sygnał.
   cond1 = TrendCandle();                                   //Umieszczenie wzsystkich w IFie skutkuje przerwaniem sprawdzania w przypadku gdy 
   cond2 = DoesNotCoverPreviousCandles();                   //któryś z kolejnych warunków jest niespełniony,przez co SignalConditionsDisplay 
   cond3 = OpenNearClose();                                 //wyświetla niepoprawne informacje
   cond4 = BodyTransposition();
   
   if(cond1 && cond2 && cond3 && cond4) 
      return true;
   else
      return false;
}
   
void SetCandleDirection() {
   if(PriceInformation[1].close>PriceInformation[1].open)
      CandleDirection=1; //a rising candle
   else{
      if(PriceInformation[1].close<PriceInformation[1].open)
         CandleDirection=-1; //a falling candle
      else
         CandleDirection=0; //a doji candle
   }
}
   
bool TrendCandle() {
   if(PriceInformation[1].high-PriceInformation[1].low != 0)
      CandleTrendPercentage = MathAbs(PriceInformation[1].close-PriceInformation[1].open)/MathAbs(PriceInformation[1].high-PriceInformation[1].low);
   else
      CandleTrendPercentage = 0;
    
   if(CandleTrendPercentage>InputTrendCandle)   
      return true;
   else
      return false;
}

bool DoesNotCoverPreviousCandles() {
   CandleHeight = PriceInformation[1].high-PriceInformation[1].low;  
   if(CandleDirection==1) {
      int HighestCandle; //it's  a fuckin index, not a value !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      double High[]; //array to keep price information
      ArraySetAsSeries(High,true); //indexing price information as a time series, sorted from the current candle downwards in High array
      CopyHigh(_Symbol,_Period,2,10,High); //copying the high price info (cena max. świecy), including current candle 2, and counting 10 candles backwards
      HighestCandle = ArrayMaximum(High,0,10);   //ArrayMaximum(High,0,10)
      HighestOrLowest = HighestCandle+1; //+1, bo łatwiej czytać - chcemy aby świeca poprzedzająca sprawdzaną miała index 1 a nie 0
      
      if(TurnOnSignalConditionsDisplay) {
         for(int i=0;i<10;i++) {
            ObjectCreate(_Symbol,"hline"+i,OBJ_HLINE,0,TimeCurrent(),High[i]);                                       
            ObjectMove(_Symbol,"hline"+i,0,TimeCurrent(),(High[i]));
         }
      }
   
      CandleCoveredPart = High[HighestCandle]-PriceInformation[1].low;
      if (CandleCoveredPart<0) CandleCoveredPart = 0;    //negative covered part means that candle does not cover previous candles, so it equals 0
      if (CandleCoveredPart>CandleHeight) CandleCoveredPart=CandleHeight; //covered part should not exceed CandleHeight
      if (CandleHeight != 0) CandleCoveredPercentage = CandleCoveredPart/CandleHeight;
      else return false;
      if(CandleCoveredPercentage<InputCandlesMaxCoveredPartPercentage) return true;
      else return false;
   }
   else if(CandleDirection==-1) {
      int LowestCandle; //it's  a fuckin index, not a value !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      double Low[]; //array to keep price information
      ArraySetAsSeries(Low,true); //indexing price information as a time series, sorted from the current candle downwards in High array
      CopyLow(_Symbol,_Period,2,10,Low); //copying the high price info (cena max. świecy), including current candle 2, and counting 10 candles backwards
      LowestCandle = ArrayMinimum(Low,0,10);   //ArrayMaximum(High,0,10)
      HighestOrLowest = LowestCandle+1;

      if(TurnOnSignalConditionsDisplay) {
         for(int i=0;i<10;i++) {
            ObjectCreate(_Symbol,"hline"+i,OBJ_HLINE,0,TimeCurrent(),Low[i]);                                        
            ObjectMove(_Symbol,"hline"+i,0,TimeCurrent(),(Low[i]));
         }
      }  

      CandleCoveredPart = PriceInformation[1].high-Low[LowestCandle];
      if (CandleCoveredPart<0) CandleCoveredPart = 0;
      if (CandleCoveredPart>CandleHeight) CandleCoveredPart=CandleHeight; //covered part should not exceed CandleHeight
      if (CandleHeight != 0) CandleCoveredPercentage = CandleCoveredPart/CandleHeight;
      else return false;
      //Comment("CandleHalf: ",CandleHalf,"\n","Lowest candle of 1-10: ",Low[LowestCandle],"\n",Low[1],"\n",Low[2],"\n",Low[3],"\n",Low[4],"\n",Low[5],"\n",Low[6],"\n",Low[7],"\n",Low[8],"\n",Low[9],"\n",Low[10]); //to erase
      if(CandleCoveredPercentage<InputCandlesMaxCoveredPartPercentage) return true;
      else return false;
   }
   else {
      HighestOrLowest = 0; //zero tylko w przypadku świecy doji
      return false;
   }
}

bool OpenNearClose() {
   return true;
}

bool BodyTransposition() { 
   if(CandleTrendPercentage<0.8) {
      double UpperPlusLowerShadows = PriceInformation[1].high-PriceInformation[1].close+PriceInformation[1].open-PriceInformation[1].low;
      if(CandleDirection==1) {
         double UpperShadow = PriceInformation[1].high-PriceInformation[1].close;
         if(UpperShadow<=0.5*UpperPlusLowerShadows)
            return true;
         else
            return false;
      }
      else if(CandleDirection==-1) {
         double LowerShadow = PriceInformation[1].close-PriceInformation[1].low;
         if(LowerShadow<=0.5*UpperPlusLowerShadows)
            return true;
         else
            return false;
      }
      else        //CandleDirection = 0;
         return false;
   } 
   else       //korpus jest wystarczająco duży
      return false;
}

bool MovingAverageDistance() {  //własnej roboty chujowy sygnał
   double myMovingAverageArray[];
   int movingAverageDefinition = iMA(_Symbol,_Period,20,0,MODE_SMA,PRICE_CLOSE); //last 20 candles, 0-candles shift to left or right
   ArraySetAsSeries(myMovingAverageArray,true); //sort the price array from current candle downwards
   CopyBuffer(movingAverageDefinition,0,0,3,myMovingAverageArray); //defined EA,one line, current candle, 3 candles, store result
   double myMovingAverageValue = myMovingAverageArray[0]; //calculate EA for the current value
   double MACandleHeight = PriceInformation[1].high-PriceInformation[1].low;
   
   if(CandleDirection==1) {
      if(PriceInformation[1].low-MACandleHeight/2<=myMovingAverageValue)
         return true;
      else
         return false;
   }
   else if(CandleDirection==-1) {
      if(PriceInformation[1].high+MACandleHeight/2>=myMovingAverageValue)
         return true;
      else
         return false;
   }
   else
      return false;
}

void OpenOrder() {

   TempFlagOpenOrderEnter++;
   
   ObjectCreate(_Symbol,"MyArrow",OBJ_ARROW,0,TimeCurrent(),(PriceInformation[0].high));  
   ObjectSetInteger(0,"MyArrow",OBJPROP_COLOR,clrGreen);                                  
   ObjectSetInteger(0,"MyArrow",OBJPROP_WIDTH,5);                                         
   ObjectMove(_Symbol,"MyArrow",0,TimeCurrent(),(PriceInformation[0].high));
   
   //ObjectCreate(_Symbol,"SignalVerifier",OBJ_TEXT)
   
   int offset = 1;     // offset from the current price to place the order, in points
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-offset*_Point,_Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID)+offset*_Point,_Digits);
   CandleHeight = PriceInformation[1].high-PriceInformation[1].low;

   MqlTradeRequest myrequest;
   MqlTradeResult myresult;
   ZeroMemory(myrequest);
   myrequest.action = TRADE_ACTION_PENDING;                                        
   myrequest.symbol = _Symbol;
   myrequest.volume = 1;
   myrequest.type_filling = ORDER_FILLING_IOC;
   myrequest.deviation = 5;
   
   if(CandleDirection==1) {
      double DesiredBuyPrice = NormalizeDouble(PriceInformation[1].high+InputTicksToOpen*_Point,_Digits);
      if(Ask>=DesiredBuyPrice) {
         TempFlagOrdersCount++;
         
         myrequest.type = ORDER_TYPE_BUY_LIMIT;                                     
         myrequest.price = Ask; // NIE TRZEBA NORMALIZOWAĆ????????
         myrequest.sl = NormalizeDouble(PriceInformation[1].low-InputTicksToClose*_Point,_Digits);
         myrequest.tp = NormalizeDouble(PriceInformation[1].high+2*CandleHeight,_Digits);
         myrequest.type_time = ORDER_TIME_SPECIFIED;
         myrequest.expiration = TimeTradeServer()+PeriodSeconds(_Period);
         myrequest.comment = "myresult.retcode: "+myresult.retcode;
         
         if(!OrderSend(myrequest,myresult)) {
            errors++;
            Comment("Result code: "+myresult.retcode+"\n"+
                    "myrequest.price: "+myrequest.price+"\n"+
                    "Current ask: "+NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits)+"\n"+
                    "errors: "+errors);
         }

         ThisCandleOpenOrders=1;
      }
      else {
         
      }
   }
/* else if(CandleDirection==-1) {
      double DesiredSellPrice = NormalizeDouble(PriceInformation[1].low-InputTicksToOpen*_Point,_Digits);
      if(Bid<=DesiredSellPrice) {
         TempFlagOrdersCount++;
        
         myrequest.type = ORDER_TYPE_SELL_LIMIT;
         myrequest.price = Bid; // NIE TRZEBA NORMALIZOWAĆ????????
         //myrequest.sl = NormalizeDouble(PriceInformation[1].high+InputTicksToClose*_Point,_Digits);
         //myrequest.tp = NormalizeDouble(PriceInformation[1].low-2*CandleHeight,_Digits);
         myrequest.type_time = ORDER_TIME_SPECIFIED;
         myrequest.expiration = TimeTradeServer()+PeriodSeconds(_Period);
         myrequest.comment = "myresult.retcode: "+myresult.retcode;
         
         if(!OrderSend(myrequest,myresult)) {
            errors++;
            Comment("Result code: "+myresult.retcode+"\n"+
                    "myrequest.price: "+myrequest.price+"\n"+
                    "Current ask: "+NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits)+"\n"+
                    "errors: "+errors);
         }

         ThisCandleOpenOrders=1;
      }
      else {
      
      }
   }
*/

            
         
        
      //PrintFormat("OrderSend error %d",GetLastError());             // if unable to send the request, output the error code
      //PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order); //--- information about the operation
         
}

void ViewControlInfo() {
   //Comment("Trend candle: ",DoubleToString(100*NormalizeDouble(CandleTrendPercentage,3),1),"%\n",
   //        "No previous candles covering: ",DoesNotCoverPreviousCandles(),"\n",
   //        _Period);
}

void SignalConditionsDisplay() { //shows all the conditions of function SignalToOpen() - which of them are met and which are not met

   TextObjectName = TextObjectIncrement;
   ObjectCreate(_Symbol,TextObjectName,OBJ_TEXT,0,TimeCurrent()-PeriodSeconds(_Period),PriceInformation[1].low);
   ObjectSetString(0,TextObjectName,OBJPROP_TEXT,"    "+DoubleToString(NormalizeDouble(CandleTrendPercentage,2),2)+"    "+
                                                        DoubleToString(NormalizeDouble(CandleCoveredPercentage,2),2)+"    "+
                                                        HighestOrLowest);
                                                               //for now it only shows CandleTrendPercentage - the rest to be done (but also check if CandleTrendPerc is correct)
   ObjectSetInteger(0,TextObjectName,OBJPROP_COLOR,clrRed); //docelowo clrMidnightBlue
   ObjectSetInteger(0,TextObjectName,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,TextObjectName,OBJPROP_FONTSIZE,9);
   ObjectSetDouble(0,TextObjectName,OBJPROP_ANGLE,-90.0);
   //ObjectSetInteger(0,TextObjectName,OBJPROP_WIDTH,5);
   ObjectMove(_Symbol,TextObjectName,0,TimeCurrent()-PeriodSeconds(_Period),PriceInformation[1].low);
   TextObjectIncrement++;
}

//double OnTester()
//{
//return(0.0);
//}


