
/*

This is the sketch for my automatic cat feeder project

Credits:
Button handling taken from: Salsaman - http://forum.arduino.cc/index.php?topic=14479.0
Motor control: Bildr - http://bildr.org/2012/04/tb6612fng-arduino/
Piezo control: Can't remember/find again where I found the code
Alarm: http://forum.arduino.cc/index.php?topic=37693.0


This sketch utilitzes a DS1307 RTC connected via I2C and Wire lib to keep accurate time
It also uses a motor driver breakout board to make controlling 1 or 2 motors simple and flexible
With the motor breakout board, you can control the direction and speed of the motor relatively easily

Pre-made kits/parts used:
DS1307 Real Time Clock breakout board kit: http://www.adafruit.com/product/264
SparkFun Motor Driver - Dual TB6612FNG (1A): https://www.sparkfun.com/products/9457


****** Possible future to-dos ******
1. Add Internet (via web browser) control of the feeders
2. Add a new button function - hold down the button for a few seconds, and keep holding to continuosly dispense food
   until the button is released
3. When Internet-enabled, add some kind of alert/notification when the canisters need to be refilled
****** Possible future to-dos ******



******Troubleshooting note*****
Week of 7/12/15 I was having problems with trying to use 2 buttons with the 2 motors. (1 button, 1 motor was working just fine)
I modified the checkButton() function to accept 1 parameter, and added some 'if' statements inside that function
to be able to return values 4-6 for ButtonB (and still use values 1-3 for ButtonA). And made a few other little changes
to accomodate ButtonB. However, in practice, ButtonA wasn't working at all, and when pressing ButtonB, it would
trigger motorA instead of B!
Took a while to figure it out, but it had something to do with the 'Button variables'. So what I did is set up a 
checkButtonA() and checkButtonB(). Then set up whole new set of 'Button variables' for ButtonB, and just tacked on
the letter 'B' to each of those. Then modified each reference to those new ones inside the function so that it would
utilize the new, 'B' variables.
Did not need to set up new 'Button timing variables'


Possible troubleshooting note!
The code that runs the piezo speaker uses a function called delayMicroseconds()
This may possibly interfere with the alarm triggering according to:
http://forum.arduino.cc/index.php?topic=37693.0
I tried to use alarm.delayMicroseconds(), but it doesn't look like that exists
Hopefully it won't make any problems, but need to keep that in mind just in case!!

*/

#include <Wire.h>
#include "RTClib.h"
#include <Time.h> //For some reason these 2 'time' includes has to be below the above 2 includes
#include <TimeAlarms.h> // "" ""
 
 
RTC_DS1307 RTC;




// Note: With the current motor/speed of motor (using 12V power supply, current 'ramp up delay', 
// and current food dispenser...
// in the function, moveMotorHighLevel, here is a rough chart of seconds-to-dispenser-flapper turns:
// 
// .5 second    = 1/2 flapper drop
// 1 second     = 1 flapper drop
// 3 seconds    = 2 flapper drops
// 5.75 seconds = 3 flapper drops
// 7.95 seconds = 4 flapper drops
//
// Again, the above is based on many variables - motor speeds - rated RPM, voltage applied to motor,
// ramp-up delay in code, whether or not to run motor full speed in code, etc., and type of food dispenser
// You will likely have to do some tests to figure out how many seconds apply to various # of flapper drops
// with your code/parts


// User constants
const int secondsToTurnMotorA = 5.75; // How many seconds motor A will spin when alarm is triggered (This will be for a full meal)
const int secondsToTurnMotorB = 3; // How many seconds motor B will spin when alarm is triggered (This will be for a full meal)

const int secondsToTurnMotorAViaSinglePressButtonA = 1; // How many seconds motor A will spin when button A is pressed
const int secondsToTurnMotorBViaSinglePressButtonB = .5; // How many seconds motor B will spin when button B is pressed

const int secondsToTurnMotorAViaDoublePressButtonA = 3; // How many seconds motor A will spin when button A is double-clicked
const int secondsToTurnMotorBViaDoublePressButtonB = 1; // How many seconds motor B will spin when button B is double-clicked

const int secondsToTurnMotorAViaLongPressButtonA = 5.75; // How many seconds motor A will spin when button A is held down for a couple seconds
const int secondsToTurnMotorBViaLongPressButtonB = 3; // How many seconds motor B will spin when button B is held down for a couple seconds
// End user constants



#define LEDA 13    // the pin for the green status LED (A)
#define LEDB 4    // the pin for the green status LED (B)

#define BUTTONA 7  // the input pin where the pushbutton A is connected
#define BUTTONB 2  // the input pin where the pushbutton B is connected

const int motorA = 1;
const int motorB = 0;


int buzzPin = 6; // piezo


//motor stuff
//motor A connected between A01 and A02
//motor B connected between B01 and B02
int STBY = 10; //standby

//Motor A
int PWMA = 3; //Speed control 
int AIN1 = 9; //Direction
int AIN2 = 8; //Direction

//Motor B
int PWMB = 5; //Speed control
int BIN1 = 11; //Direction
int BIN2 = 12; //Direction

int iMotorSpeed = 0; //variable to 'ramp up' speed of motor from being stopped
//motor stuff




 
 
void setup () {
    //Serial.begin(57600); //Initialize 'serial port' ??
    Wire.begin(); //Initialize I2C/Wire ??
    RTC.begin(); //Initialize Real Time Clock
    
    
    
    // LED A, Button A
    pinMode(LEDA, OUTPUT);    // tell Arduino LEDA is an output
    digitalWrite(LEDA, LOW); // Status LED A for motor A - should be off initially
    pinMode(BUTTONA, INPUT);  // and BUTTONA is an input
    digitalWrite(BUTTONA, HIGH); // (Not sure what this is for, but was done in the One_Button_3_Functions sketch)
    
    // LED B, Button B
    pinMode(LEDB, OUTPUT);    // tell Arduino LEDB is an output
    digitalWrite(LEDB, LOW); // Status LED B for motor B - should be off initially
    pinMode(BUTTONB, INPUT);  // and BUTTONB is an input
    digitalWrite(BUTTONB, HIGH); // (Not sure what this is for, but was done in the One_Button_3_Functions sketch)
  
  
  
    // Motor driver board (again, Sparkfun's Dual TB6612FNG) stuff
    // set the below pins as output pins
    pinMode(STBY, OUTPUT);

    pinMode(PWMA, OUTPUT);
    pinMode(AIN1, OUTPUT);
    pinMode(AIN2, OUTPUT);
    
    pinMode(PWMB, OUTPUT);
    pinMode(BIN1, OUTPUT);
    pinMode(BIN2, OUTPUT);
    // Motor stuff
    
    
    // set the Piezo speaker to output
    pinMode(buzzPin, OUTPUT);
 
 
    DateTime now = RTC.now();
    //setTime(8,27,0,1,1,10); // set time to 8:27:00am Jan 1 2010
    setTime(now.hour(),now.minute(),0,now.day(),now.month(),now.year()); // set time to current time from DS1307
    
    
    // ***************************************************************************
    // ***************************************************************************
    // *********************** ACTUAL TIMERS GO HERE *****************************
    // ***************************************************************************
    Alarm.alarmRepeat(5,15,0, AlarmA);  // 5:15am every day
    Alarm.alarmRepeat(17,15,0, AlarmA); // 5:15pm every day
    // ***************************************************************************
    // ************************* END ACTUAL TIMERS *******************************
    // ***************************************************************************
    // ***************************************************************************
 
 
}
 
void loop () {
    
    DateTime now = RTC.now();
    
    // NOTE - the below line needs to be here! Don't comment it out! I had it above in the 'setup()' only, but the alarm
    // wasn't triggering until several seconds later when I had it like this. As soon as I put it below, it
    // started working as expected!
    setTime(now.hour(),now.minute(),0,now.day(),now.month(),now.year()); // set time to current time from DS1307
 
 
    //Serial.print(now.year(), DEC);
    //Serial.print('/');
    //Serial.print(now.month(), DEC);
    //Serial.print('/');
    //Serial.print(now.day(), DEC);
    //Serial.print(' ');
    //Serial.print(now.hour(), DEC);
    //Serial.print(':');
    //Serial.print(now.minute(), DEC);
    //Serial.print(':');
    //Serial.print(now.second(), DEC);
    //Serial.println();
    
    
 
    
    // Get button event and act accordingly (watch for button presses, execute appropriate function)
    //int b = checkButton();
    int b1 = checkButtonA(); // Check Button A
    int b2 = checkButtonB(); // Check Button B
    
    if (b1 == 1) clickEvent(1); // single-click on button A was detected
    if (b1 == 2) doubleClickEvent(1); // double-click on button A was detected
    if (b1 == 3) holdEvent(1); // button-hold on button A was detected
    
    if (b2 == 1) clickEvent(2); // single-click on button B was detected
    if (b2 == 2) doubleClickEvent(2); // double-click on button B was detected
    if (b2 == 3) holdEvent(2); // button-hold on button B was detected

    
    
    
 
 
    //Serial.println();
    //delay(3000);
    
    
    //********************************WARNING!!!****************************
    // DO NOT INCREASE THE VALUE OF THE BELOW ALARM.DELAY LINE - THE LARGER THE NUMBER THE MORE LIKELY
    // THAT THE SKETCH WILL NOT READ THE STATE OF THE BUTTON(S)
    // PROBABLY BECAUSE FOR EVERY CYCLE THAT THIS MAIN 'LOOP' IS EXECUTED, THE CODE IS PAUSED FOR
    // THAT LONG (CURRENTLY 100 MILLISECONDS), THEREFORE NOT READING THE STATE OF THE BUTTON FOR THAT ENTIRE SECOND!!!
    // AND WE CAN'T TAKE THE BELOW LINE OUT BECAUSE IF WE DO, FOR SOME REASON THE ALARM(S) WON'T TRIGGER :(
    Alarm.delay(100); // Delay one-tenth of a second
    //*******************************END WARNING****************************
    
    
}
//********************** End main 'loop()' *******************************************************************************************







// ***************************
// BELOW ARE VARIOUS FUNCTIONS
// ***************************


// function to be called when an alarm triggers:
void AlarmA(){
  

   // MAIN EXECUTION OF ALARM CODE WHERE THINGS HAPPEN!!!
   //
   playBreakfastDinnerTones(); // self-explanatory, right?
   digitalWrite(LEDA, HIGH);  // turn status LEDA on
   moveMotorHighLevel(secondsToTurnMotorA, motorA); // Run motor A (dispense some food)
   digitalWrite(LEDA, LOW); // turn status LEDA off
  
   Alarm.delay(1000); // Pause for just a second to be safe
  
   digitalWrite(LEDB, HIGH);  // turn status LEDB on
   moveMotorHighLevel(secondsToTurnMotorB, motorB); // Run motor B (dispense some food)
   digitalWrite(LEDB, LOW); // turn status LEDB off
   //
   // MAIN EXECUTION OF ALARM CODE WHERE THINGS HAPPEN!!!
  
  
} // AlarmA()






// Probably not the best name for the function, but I mean 'low level' like in programming - 
// low level programming, as opposed to higher-level programming
// So the 'lowLevel' part of the name is not implying that the motor is moving 'lower' or 'slower' or
// with less torque or anything like that
void moveMotorLowLevel(int motor, int speed, int direction){
  //Move specific motor at speed and direction
  //motor: 0 for B 1 for A
  //speed: 0 is off, and 255 is full speed
  //direction: 0 clockwise, 1 counter-clockwise

  digitalWrite(STBY, HIGH); //disable standby

  boolean inPin1 = LOW;
  boolean inPin2 = HIGH;

  if(direction == 1){
    inPin1 = HIGH;
    inPin2 = LOW;
  }

  if(motor == motorA){
    digitalWrite(AIN1, inPin1);
    digitalWrite(AIN2, inPin2);
    analogWrite(PWMA, speed);
  } else{
    digitalWrite(BIN1, inPin1);
    digitalWrite(BIN2, inPin2);
    analogWrite(PWMB, speed);
  }
} // moveMotorLowLevel()


// Just as the 'lowLevel' name in the above function, the 'highLevel' part of this function's name has
// nothing to do with it's speed or torque, it's referring to the complexity of t he code inside the 
// function...that's all
void moveMotorHighLevel(int numOfSecondsToTurnMotor, int whichMotor)  {
  // whichMotor: 0 for B, 1 for A
  
  int i = 0;

  //Don't spin motor full speed immediately - ramp it up!
  for (i = 1; i < 256; i++) { // loop from 1 to 255
    moveMotorLowLevel(whichMotor, i, 1); //motor A or B, speed from 1 to 255, spin left
    Alarm.delay(10); // give a small delay between each speed change
  }
      
  Alarm.delay(numOfSecondsToTurnMotor * 1000); //wait X amount seconds which will run the motor full speed for X amount of seconds
  // Alarm.delay(x * 1000); //wait X amount seconds which will run the motor full speed for X amount of seconds

  stopMotor(whichMotor);
 
} // moveMotorHighLevel()




void stopMotor(int whichMotorToStop){
  
  //enable standby (this is not enough alone to turn off the motor! sooo...) 
  digitalWrite(STBY, LOW);
  
  if(whichMotorToStop == motorA){
    digitalWrite(AIN1, LOW); // turn pin low for motor A
    digitalWrite(AIN2, LOW); // turn pin low for motor A
  } else {  // orrrr
    digitalWrite(BIN1, LOW); // turn pin low for motor B
    digitalWrite(BIN2, LOW); // turn pin low for motor B
  }
  
} // stopMotor()




void playBreakfastDinnerTones()  {
 
 // This will create 2 long tones followed by 3 quick tones
 // I have no idea how it works
 
 for (long i = 0; i < 2024; i++ ) {
          digitalWrite(buzzPin, HIGH);
          delayMicroseconds(244);
          digitalWrite(buzzPin, LOW);
          delayMicroseconds(244);
      }
      delay(500);
      for (long i = 0; i < 2024; i++ ) {
          digitalWrite(buzzPin, HIGH);
          delayMicroseconds(244);
          digitalWrite(buzzPin, LOW);
          delayMicroseconds(244);
      }
      delay(500);
        for (long i = 0; i < 512; i++ ) {
          digitalWrite(buzzPin, HIGH);
          delayMicroseconds(244);
          digitalWrite(buzzPin, LOW);
          delayMicroseconds(244);
      }
      delay(500);
        for (long i = 0; i < 512; i++ ) {
          digitalWrite(buzzPin, HIGH);
          delayMicroseconds(244);
          digitalWrite(buzzPin, LOW);
          delayMicroseconds(244);
      }
      delay(500);
        for (long i = 0; i < 512; i++ ) {
          digitalWrite(buzzPin, HIGH);
          delayMicroseconds(244);
          digitalWrite(buzzPin, LOW);
          delayMicroseconds(244);
      } 
  
  
} // playBreakfastDinnerTones()
















// ************ Everything below this line is for the button(s) ************************



void clickEvent(int whichButtonWasPushed) {
   // Code for when a single click is detected
   
   if (whichButtonWasPushed == 1) {
     // Button A was pushed
     digitalWrite(LEDA, HIGH);  // turn status LEDA on
     moveMotorHighLevel(secondsToTurnMotorAViaSinglePressButtonA, motorA); // Motor A
     digitalWrite(LEDA, LOW); // turn status LEDA off
   } else {
     // Button B was pushed
     digitalWrite(LEDB, HIGH);  // turn status LEDB on
     moveMotorHighLevel(secondsToTurnMotorBViaSinglePressButtonB, motorB); // Motor B
     digitalWrite(LEDB, LOW); // turn status LEDB off
   }
   
} // clickEvent()

void doubleClickEvent(int whichButtonWasPushed) {
   // Code for when a double click is detected
   
   if (whichButtonWasPushed == 1) {
     // Button A was pushed
     digitalWrite(LEDA, HIGH);  // turn status LEDA on
     moveMotorHighLevel(secondsToTurnMotorAViaDoublePressButtonA, motorA); // Motor A
     digitalWrite(LEDA, LOW); // turn status LEDA off
   } else {
     // Button B was pushed
     digitalWrite(LEDB, HIGH);  // turn status LEDB on
     moveMotorHighLevel(secondsToTurnMotorBViaDoublePressButtonB, motorB); // Motor B
     digitalWrite(LEDB, LOW); // turn status LEDB off
   }
   
} // doubleClickEvent()

void holdEvent(int whichButtonWasPushed) {
   // Code for when a hold (long press) is detected
   
   if (whichButtonWasPushed == 1) {
     // Button A was pushed
     digitalWrite(LEDA, HIGH);  // turn status LEDA on
     moveMotorHighLevel(secondsToTurnMotorAViaLongPressButtonA, motorA); // Motor A
     digitalWrite(LEDA, LOW); // turn status LEDA off
   } else {
     // Button B was pushed
     digitalWrite(LEDB, HIGH);  // turn status LEDB on
     moveMotorHighLevel(secondsToTurnMotorBViaLongPressButtonB, motorB); // Motor B
     digitalWrite(LEDB, LOW); // turn status LEDB off
   }

} // holdEvent()








//=================================================
//  MULTI-CLICK:  One Button, Multiple Events

// Button timing variables
int debounce = 20;          // ms debounce period to prevent flickering when pressing or releasing the button
int DCgap = 250;            // max ms between clicks for a double click event
int holdTime = 2000;        // ms hold period: how long to wait for press+hold event


// Button variables
boolean buttonVal = HIGH;   // value read from button
boolean buttonLast = HIGH;  // buffered value of the button's previous state
boolean DCwaiting = false;  // whether we're waiting for a double click (down)
boolean DConUp = false;     // whether to register a double click on next release, or whether to wait and click
boolean singleOK = true;    // whether it's OK to do a single click
long downTime = -1;         // time the button was pressed down
long upTime = -1;           // time the button was released
boolean ignoreUp = false;   // whether to ignore the button release because the click+hold was triggered
boolean waitForUp = false;        // when held, whether to wait for the up event
boolean holdEventPast = false;    // whether or not the hold event happened already


int checkButtonA() {    
   int event = 0;
   buttonVal = digitalRead(BUTTONA);
   // Button pressed down
   if (buttonVal == LOW && buttonLast == HIGH && (millis() - upTime) > debounce)
   {
       downTime = millis();
       ignoreUp = false;
       waitForUp = false;
       singleOK = true;
       holdEventPast = false;
       
       if ((millis()-upTime) < DCgap && DConUp == false && DCwaiting == true)  DConUp = true;
       else  DConUp = false;
       DCwaiting = false;
   }
   // Button released
   else if (buttonVal == HIGH && buttonLast == LOW && (millis() - downTime) > debounce)
   {        
       if (not ignoreUp)
       {
           upTime = millis();
           if (DConUp == false) DCwaiting = true;
           else
           {
               event = 2;
               DConUp = false;
               DCwaiting = false;
               singleOK = false;
           }
       }
   }
   // Test for normal click event: DCgap expired
   if ( buttonVal == HIGH && (millis()-upTime) >= DCgap && DCwaiting == true && DConUp == false && singleOK == true && event != 2)
   {
       event = 1;
       DCwaiting = false;
   }
   // Test for hold
   if (buttonVal == LOW && (millis() - downTime) >= holdTime) {
       // Trigger "normal" hold
       if (not holdEventPast)
       {
           event = 3;
           waitForUp = true;
           ignoreUp = true;
           DConUp = false;
           DCwaiting = false;
           //downTime = millis();
           holdEventPast = true;
       }

   }
   buttonLast = buttonVal;
   return event;
} // checkButtonA()
















// Button variables
boolean buttonValB = HIGH;   // value read from button
boolean buttonLastB = HIGH;  // buffered value of the button's previous state
boolean DCwaitingB = false;  // whether we're waiting for a double click (down)
boolean DConUpB = false;     // whether to register a double click on next release, or whether to wait and click
boolean singleOKB = true;    // whether it's OK to do a single click
long downTimeB = -1;         // time the button was pressed down
long upTimeB = -1;           // time the button was released
boolean ignoreUpB = false;   // whether to ignore the button release because the click+hold was triggered
boolean waitForUpB = false;        // when held, whether to wait for the up event
boolean holdEventPastB = false;    // whether or not the hold event happened already


int checkButtonB() {    
   int event = 0;
   buttonValB = digitalRead(BUTTONB);
   // Button pressed down
   if (buttonValB == LOW && buttonLastB == HIGH && (millis() - upTimeB) > debounce)
   {
       downTimeB = millis();
       ignoreUpB = false;
       waitForUpB = false;
       singleOKB = true;
       holdEventPastB = false;
       
       if ((millis()-upTimeB) < DCgap && DConUpB == false && DCwaitingB == true)  DConUpB = true;
       else  DConUpB = false;
       DCwaitingB = false;
   }
   // Button released
   else if (buttonValB == HIGH && buttonLastB == LOW && (millis() - downTimeB) > debounce)
   {        
       if (not ignoreUpB)
       {
           upTimeB = millis();
           if (DConUpB == false) DCwaitingB = true;
           else
           {
               event = 2;
               DConUpB = false;
               DCwaitingB = false;
               singleOKB = false;
           }
       }
   }
   // Test for normal click event: DCgap expired
   if ( buttonValB == HIGH && (millis()-upTimeB) >= DCgap && DCwaitingB == true && DConUpB == false && singleOKB == true && event != 2)
   {
       event = 1;
       DCwaitingB = false;
   }
   // Test for hold
   if (buttonValB == LOW && (millis() - downTimeB) >= holdTime) {
       // Trigger "normal" hold
       if (not holdEventPastB)
       {
           event = 3;
           waitForUpB = true;
           ignoreUpB = true;
           DConUpB = false;
           DCwaitingB = false;
           //downTime = millis();
           holdEventPastB = true;
       }

   }
   buttonLastB = buttonValB;
   return event;
} // checkButtonB()

