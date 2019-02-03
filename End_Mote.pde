#include <WaspSensorEvent_v30.h>
#include <WaspWIFI_PRO.h>
#include <WaspFrame.h>
#include <WaspXBee802.h>

char WASPMOTE_ID[] = "end_node";
char RX_ADDRESS[] = "0013A200416BE242";

//Global vars to measure parameters
uint8_t value = 0;  //For measure PIR
float temp;         
float humd;
float pres;
uint8_t batteryLevel;
uint8_t error;      //For the 802.15.4

pirSensorClass pir(SOCKET_1);//Select the position of the PIR sensor


void setup(){

  //////////////////////////////////////////////////
  // 1. Switch ON Serial port, RTC, ACC and Events board
  //////////////////////////////////////////////////

  // Setup for Serial port over USB
  USB.ON();
  USB.println(F("Start program"));

  // Power up the RTC and the ACC
  USB.println(F("Init RTC"));
  RTC.ON(); 
  ACC.ON();  

  // Setting time [yy:mm:dd:dow:hh:mm:ss]
  RTC.setTime("09:10:20:03:17:35:30"); //the time is not relevant
  
  // Turn on the sensor board
  Events.ON();

  //Turn on 802.15.4 module
  frame.setID(WASPMOTE_ID);
  xbee802.ON();

  // Firstly, wait for PIR signal stabilization
  value = pir.readPirSensor();
  while (value == 1)
  {
    USB.println(F("...wait for PIR stabilization"));
    delay(1000);
    value = pir.readPirSensor();    
  }
  
}

void loop()
{ 

  // Enable Free fall interrupt
  ACC.setFF(); 

  // Enable interruptions from the board
  Events.attachInt();
  
  // Getting time
  USB.print(F("Time [Day of week, YY/MM/DD, hh:mm:ss]: "));
  USB.println(RTC.getTime());

  // Deep sleep
  USB.println(F("Waspmote sleeps"));
  // Ways to awake: RTC 30 seconds and Sensors
  PWR.deepSleep("00:00:00:30", RTC_OFFSET, RTC_ALM1_MODE1, SENSOR_ON);

  // Power on the accelerometer
  ACC.ON();
  
  // Disable interruptions from the board
  ACC.unsetFF();        //Accelerometer
  Events.detachInt();   //Events board
  
  // After setting Waspmote to power-down, UART is closed, so it
  // is necessary to open it again
  USB.ON();
  USB.println(F("Waspmote wakes up!"));
  //Power on the communication module
  xbee802.ON(SOCKET0);
  //Set the power level to the minimum
  xbee802.setPowerLevel(0);

  // If the waspmote awakes due to the RTC IRQ
  if( intFlag & RTC_INT )
  {
    // clear interruption flag
    intFlag &= ~(RTC_INT);
    
    USB.println(F("-------------------------"));
    USB.println(F("RTC INT Captured"));
    USB.println(F("-------------------------"));

    //Temperature
    temp = Events.getTemperature();
    //Humidity
    humd = Events.getHumidity();
    //Pressure
    pres = Events.getPressure();
    //Battery Level
    batteryLevel = PWR.getBatteryLevel();

    //To send via 802.15.4
    frame.createFrame(ASCII);

   // define local buffer for float to string conversion
    char payload[100];
    char temp_str[10];
    char humd_str[10];
    char pres_str[10];
    
    // use dtostrf() to convert from float to string: 
    // '1' refers to minimum width
    // '3' refers to number of decimals
    dtostrf( temp, 1, 2, temp_str);
    dtostrf( humd, 1, 2, humd_str);
    dtostrf( pres, 1, 2, pres_str);

    //Build and send the frame
    snprintf((char *)payload, 100, "DataType,%s,%s,%s,%d,%d,%d,%d", temp_str, humd_str, pres_str, batteryLevel, ACC.getX(), ACC.getY(), ACC.getZ());
    frame.addSensor(SENSOR_STR, payload);
    error = xbee802.send(RX_ADDRESS, frame.buffer, frame.length);
    if (error == 0) USB.println(F("SEND data OK"));
    else USB.println(F("SEND data NOK"));
    
    ///////////////////////////////////////
    // Print temperature, humidity and pressure values (BME280 Values): for debug
    ///////////////////////////////////////
    USB.println("-----------------------------");
    USB.print("Temperature: ");
    USB.printFloat(temp, 2);
    USB.println(F(" Celsius"));
    USB.print("Humidity: ");
    USB.printFloat(humd, 1); 
    USB.println(F(" %")); 
    USB.print("Pressure: ");
    USB.printFloat(pres, 2); 
    USB.println(F(" Pa")); 
    USB.printf("Battery: %d%%\n",batteryLevel);
    USB.printf("Accelerometer [X, Y ,Z]: %d, %d, %d\n",ACC.getX(), ACC.getY(), ACC.getZ());
    USB.println("-----------------------------");  
    
    // blink LEDs
    for(int i=0; i<10; i++)
    {
      Utils.blinkLEDs(50);
    }
    
  }

  // If the waspmote awakes due to the Accelerometer IRQ
  if( intFlag & ACC_INT )
  {
    // clear interruption flag
    intFlag &= ~(ACC_INT);
    
    // print info
    USB.ON();
    USB.println(F("++++++++++++++++++++++++++++"));
    USB.println(F("++ ACC interrupt detected ++"));
    USB.println(F("++++++++++++++++++++++++++++")); 
    USB.println(); 

    // Build the frame and send
    frame.createFrame(ASCII);
    frame.addSensor(SENSOR_STR, "WarningType");
    frame.addSensor(SENSOR_STR, "Fall detected");
    error = xbee802.send(RX_ADDRESS, frame.buffer, frame.length);
    if (error == 0) USB.println(F("SEND fall alert OK"));
    else USB.println(F("SEND fall alert NOK"));

    // blink LEDs
    for(int i=0; i<10; i++)
    {
      Utils.blinkLEDs(50);
    }
    
  }   

  // If the waspmote awakes due to the Events board IRQ
  if (intFlag & SENS_INT)
  {
    
    // Load the interruption flag
    Events.loadInt();
    
    // In case the interruption came from PIR print it
    if (pir.getInt())
    {
      USB.println(F("-----------------------------"));
      USB.println(F("Interruption from PIR"));
      USB.println(F("Presence detected"));
      USB.println(F("-----------------------------"));
    } 

    // Build and send the ASCII frame
    frame.createFrame(ASCII);
    frame.addSensor(SENSOR_STR, "WarningType");
    frame.addSensor(SENSOR_STR, "Presence detected");
    error = xbee802.send(RX_ADDRESS, frame.buffer, frame.length);
    if (error == 0) USB.println(F("SEND presence alert OK"));
    else USB.println(F("SEND presence alert NOK"));
    
    // In this example, now wait for signal
    // stabilization to generate a new interruption
    // Read the sensor level
    value = pir.readPirSensor();
    
    while (value == 1)
    {
      USB.println(F("...wait for PIR stabilization"));
      delay(1000);
      value = pir.readPirSensor();
    }
  }
  
  // Clean the interruption flag
  intFlag &= ~(SENS_INT);
   
}

