/*Project implementation with just one connection to the network*/

#include <WaspSensorEvent_v30.h>
#include <WaspWIFI_PRO.h>
#include <WaspFrame.h>
#include <WaspXBee802.h>

#include <Countdown.h>
#include <FP.h>
#include <MQTTClient.h>
#include <MQTTConnect.h>
#include <MQTTFormat.h>
#include <MQTTLogging.h>
#include <MQTTPacket.h>
#include <MQTTPublish.h>
#include <MQTTSubscribe.h>
#include <MQTTUnsubscribe.h>

// Sockets
///////////////////////////////////////
uint8_t socket_WiFi = SOCKET1;
uint8_t socket_802 = SOCKET0;
///////////////////////////////////////

// TCP/IP server settings
///////////////////////////////////////
//char HOST[]        = "10.49.1.32"; //MQTT Broker
//char HOST[] = "192.168.0.160";     //Fer test
char HOST[] = "192.168.137.187";
char REMOTE_PORT[] = "1883";  //MQTT without security
char LOCAL_PORT[]  = "3000";  //idk its functionallity
///////////////////////////////////////

// Variables definition, for reading data, or for determine the status of a connection
uint8_t error; //Used for 802.15.4 and WiFi connections
uint8_t status;
unsigned long previous;
uint16_t socket_handle = 0;
uint8_t value = 0;
float temp;
float humd;
float pres;
uint8_t batteryLevel;

//PIR SENSOR position, static
pirSensorClass pir(SOCKET_1);


void setup()
{
  
  // Switch ON serial port: for debuging purposes
  USB.ON();
  USB.println(F("Start program"));

  // Power ON the RTC and the Accelerometer
  USB.println(F("Init RTC and the ACC"));
  RTC.ON(); 
  ACC.ON();  

  // Setting time [yy:mm:dd:dow:hh:mm:ss]; 2009/10/20; X, 17:35:30
  RTC.setTime("09:10:20:03:17:35:30");
  
  // Turn on the sensor board
  USB.println(F("Init Sensor Board"));
  Events.ON();

  // init XBee
  USB.println(F("Init 802.15.4"));
  xbee802.ON(socket_802);

  // Firstly, wait for PIR signal stabilization
  value = pir.readPirSensor();
  while (value == 1)
  {
    USB.println(F("...wait for PIR stabilization"));
    delay(1000);
    value = pir.readPirSensor();    
  }

  //WiFi Connection
   //////////////////////////////////////////////////
  // Switch ON WIFI
  //////////////////////////////////////////////////
  USB.println(F("Init WiFi"));
  error = WIFI_PRO.ON(socket_WiFi);

  if ( error == 0 )
  {
    USB.println(F("\t1. WiFi switched ON"));
  }
  else
  {
    USB.println(F("\t1. WiFi did not initialize correctly"));
  }

  //////////////////////////////////////////////////
  // Check if connected to WiFi
  //////////////////////////////////////////////////

  // get actual time
  previous = millis();

  // check connectivity
  status =  WIFI_PRO.isConnected();

  // check if module is connected
  if ( status == true )
  {
    USB.print(F("\t2. WiFi is connected OK"));
    USB.print(F("\t Time(ms):"));
    USB.println(millis() - previous);

    // get IP address
    error = WIFI_PRO.getIP();

    if (error == 0)
    {
      USB.print(F("\tIP address: "));
      USB.println( WIFI_PRO._ip );
    }
    else
    {
      USB.println(F("\tgetIP error"));
    }
  }
  else
  {
    USB.print(F("\t2. WiFi is connected ERROR"));
    USB.print(F("\t Time(ms):"));
    USB.println(millis() - previous);
  }

  //////////////////////////////////////////////////
  // 3. TCP
  //////////////////////////////////////////////////

  // Check if module is connected
  if (status == true)
  { 

    ////////////////////////////////////////////////
    // 3.1. Open TCP socket
    ////////////////////////////////////////////////
    error = WIFI_PRO.setTCPclient( HOST, REMOTE_PORT, LOCAL_PORT);

    // check response
    if (error == 0)
    {
      // get socket handle (from 0 to 9)
      socket_handle = WIFI_PRO._socket_handle;

      USB.print(F("\t3.1. Open TCP socket OK in handle: "));
      USB.println(socket_handle, DEC);
    }
    else
    {
      USB.println(F("\t3.1. Error calling 'setTCPclient' function"));
      WIFI_PRO.printErrorCode();
      status = false;
    }
  }

  //Inicialize the MQTT Client: publisher
  if(status == true){
    
    /// Set initial conditions
    MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
    MQTTString topicString = MQTTString_initializer;
    unsigned char buf[200];     //Buffer length
    int buflen = sizeof(buf);   
    unsigned char payload[100];//Payload length

    // options
    data.clientID.cstring = (char*)"Edge-Node"; 
    data.keepAliveInterval = 30;      //Sending Ping to keep alive the connection
    data.cleansession = 1;            //idk
    int len = MQTTSerialize_connect(buf, buflen, &data);//1
    }
}

void loop()
{ 
  //Keep waiting for a 802.15.4 mesagge
  //up to 30 secs
  // receive XBee packet (wait for 10 seconds)
  error = xbee802.receivePacketTimeout( 10000 );
  
  // check answer  
  if( error == 0 ) 
  {
    // Show data stored in '_payload' buffer indicated by '_length'
    USB.print(F("Data: "));  
    USB.println( xbee802._payload, xbee802._length);
    
    // Show data stored in '_payload' buffer indicated by '_length'
    USB.print(F("Length: "));  
    USB.println( xbee802._length,DEC);
  }
  else
  {
    // Print error message:
    /*
     * '7' : Buffer full. Not enough memory space
     * '6' : Error escaping character within payload bytes
     * '5' : Error escaping character in checksum byte
     * '4' : Checksum is not correct    
     * '3' : Checksum byte is not available 
     * '2' : Frame Type is not valid
     * '1' : Timeout when receiving answer   
    */
    USB.print(F("Error receiving a packet:"));
    USB.println(error,DEC);     
  }
  
  //Measure different parameters and send the information: ~like RTC
  
  
}

/*
#include <WaspSensorEvent_v30.h>
#include <WaspWIFI_PRO.h>
#include <WaspFrame.h>

#include <Countdown.h>
#include <FP.h>
#include <MQTTClient.h>
#include <MQTTConnect.h>
#include <MQTTFormat.h>
#include <MQTTLogging.h>
#include <MQTTPacket.h>
#include <MQTTPublish.h>
#include <MQTTSubscribe.h>
#include <MQTTUnsubscribe.h>

// choose socket (SELECT USER'S SOCKET)
///////////////////////////////////////
uint8_t socket = SOCKET1;
///////////////////////////////////////


// choose TCP server settings
///////////////////////////////////////
//char HOST[]        = "10.49.1.32"; //MQTT Broker
//char HOST[] = "192.168.0.160"; //Fer test
char HOST[] = "192.168.137.187";
char REMOTE_PORT[] = "1883";  //MQTT without security
char LOCAL_PORT[]  = "3000";
///////////////////////////////////////

uint8_t error;
uint8_t status;
unsigned long previous;
uint16_t socket_handle = 0;
uint8_t value = 0;
float temp;
float humd;
float pres;
uint8_t batteryLevel;


pirSensorClass pir(SOCKET_1);


void setup(){


  //////////////////////////////////////////////////
  // 1. Switch ON Serial port, RTC, ACC and Events board
  //////////////////////////////////////////////////

  // Setup for Serial port over USB
  USB.ON();
  USB.println(F("Start program"));

  // Powers RTC up, init I2C bus and read initial values
  USB.println(F("Init RTC"));
  RTC.ON(); 
  ACC.ON();  

  // Setting time [yy:mm:dd:dow:hh:mm:ss]
  RTC.setTime("09:10:20:03:17:35:30");
  
  // Turn on the sensor board
  Events.ON();

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

  //Enable Free fall interrupt
  ACC.setFF(); 

  // Enable interruptions from the board
  Events.attachInt();
  
  // Getting time
  USB.print(F("Time [Day of week, YY/MM/DD, hh:mm:ss]: "));
  USB.println(RTC.getTime());


  // Setting Alarm1
  //RTC.setAlarm1("20:17:36:00",RTC_ABSOLUTE,RTC_ALM1_MODE2);
  
  // Getting Alarm1
  //USB.print(F("Alarm1: "));
  //USB.println(RTC.getAlarm1());  
  
  // Setting Waspmote to Low-Power Consumption Mode  
  //USB.println(F("Waspmote goes to sleep..."));
  //PWR.sleep(SENSOR_ON, ALL_OFF);  
  

  PWR.deepSleep("00:00:00:10", RTC_OFFSET, RTC_ALM1_MODE1, SENSOR_ON);

  //Power on the accelerometer
  ACC.ON();
  
  // Disable interruptions from the board
  ACC.unsetFF();        //Accelerometer
  Events.detachInt();   //Events board
  
  // After setting Waspmote to power-down, UART is closed, so it
  // is necessary to open it again
  USB.ON();
  
  USB.println(F("Waspmote wakes up!"));


  //////////////////////////////////////////////////
  // Switch ON WIFI
  //////////////////////////////////////////////////
  error = WIFI_PRO.ON(socket);

  if ( error == 0 )
  {
    USB.println(F("1. WiFi switched ON"));
  }
  else
  {
    USB.println(F("1. WiFi did not initialize correctly"));
  }

  //////////////////////////////////////////////////
  // Check if connected to WiFi
  //////////////////////////////////////////////////

  // get actual time
  previous = millis();

  // check connectivity
  status =  WIFI_PRO.isConnected();

  // check if module is connected
  if ( status == true )
  {
    USB.print(F("2. WiFi is connected OK"));
    USB.print(F(" Time(ms):"));
    USB.println(millis() - previous);

    // get IP address
    error = WIFI_PRO.getIP();

    if (error == 0)
    {
      USB.print(F("IP address: "));
      USB.println( WIFI_PRO._ip );
    }
    else
    {
      USB.println(F("getIP error"));
    }
  }
  else
  {
    USB.print(F("2. WiFi is connected ERROR"));
    USB.print(F(" Time(ms):"));
    USB.println(millis() - previous);
  }



  //////////////////////////////////////////////////
  // 3. TCP
  //////////////////////////////////////////////////

  // Check if module is connected
  if (status == true)
  { 

    ////////////////////////////////////////////////
    // 3.1. Open TCP socket
    ////////////////////////////////////////////////
    error = WIFI_PRO.setTCPclient( HOST, REMOTE_PORT, LOCAL_PORT);

    // check response
    if (error == 0)
    {
      // get socket handle (from 0 to 9)
      socket_handle = WIFI_PRO._socket_handle;

      USB.print(F("3.1. Open TCP socket OK in handle: "));
      USB.println(socket_handle, DEC);
    }
    else
    {
      USB.println(F("3.1. Error calling 'setTCPclient' function"));
      WIFI_PRO.printErrorCode();
      status = false;
    }
  }

  if (status == true)
  { 
  
    /// Publish MQTT
    MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
    MQTTString topicString = MQTTString_initializer;
    unsigned char buf[200];
    int buflen = sizeof(buf);
    unsigned char payload[100];

    // options
    data.clientID.cstring = (char*)"mt1";
    data.keepAliveInterval = 30;
    data.cleansession = 1;
    int len = MQTTSerialize_connect(buf, buflen, &data);//1

    
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
      battLevel = PWR.getBatteryLevel();
      
      ///////////////////////////////////////
      // Print temperature, humidity and pressure values (BME280 Values)
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
      USB.print("Battery level: ");
      USB.println("-----------------------------");


      // define local buffer for float to string conversion
      char temp_str[10];
      char humd_str[10];
      char pres_str[10];
      char batt_str[10];
      
      // use dtostrf() to convert from float to string: 
      // '1' refers to minimum width
      // '3' refers to number of decimals
      dtostrf( temp, 1, 2, temp_str);
      dtostrf( humd, 1, 2, humd_str);
      dtostrf( pres, 1, 2, pres_str);
      dtostrf( batt, 1, 2, batt_str);

      // Topic and message
      //topicString.cstring = (char *)"g0/mota1/temperature";
      topicString.cstring = (char *) "test/data";
      snprintf((char *)payload, 100, "Temp: %s, Humd: %s & Press: %s", temp_str, humd_str, pres_str);
      
      //Format the message and send it
      int payloadlen = strlen((const char*)payload);
  
      len += MQTTSerialize_publish(buf + len, buflen - len, 0, 0, 0, 0, topicString, payload, payloadlen); //2
  
      len += MQTTSerialize_disconnect(buf + len, buflen - len); //3/
  
      ////////////////////////////////////////////////
      // 3.2. send data
      ////////////////////////////////////////////////
      error = WIFI_PRO.send( socket_handle, buf, len);
  
      // check response
      if (error == 0)
      {
        USB.println(F("3.2. Send data OK"));
      }
      else
      {
        USB.println(F("3.2. Error calling 'send' function"));
        WIFI_PRO.printErrorCode();
      }
      
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
  
      // blink LEDs
      for(int i=0; i<10; i++)
      {
        Utils.blinkLEDs(50);
      }
      
      // Topic and message
      //topicString.cstring = (char *)"g0/mota1/temperature";
      topicString.cstring = (char *) "test/Warnings";
      snprintf((char *)payload, 100, "Fall detected", temp, humd, pres);
      
      //Format the message and send it
      int payloadlen = strlen((const char*)payload);
  
      len += MQTTSerialize_publish(buf + len, buflen - len, 0, 0, 0, 0, topicString, payload, payloadlen); //2//
  
      len += MQTTSerialize_disconnect(buf + len, buflen - len); //3//
  
      ////////////////////////////////////////////////
      // 3.2. send data
      ////////////////////////////////////////////////
      error = WIFI_PRO.send( socket_handle, buf, len);
  
      // check response
      if (error == 0)
      {
        USB.println(F("3.2. Send data OK"));
      }
      else
      {
        USB.println(F("3.2. Error calling 'send' function"));
        WIFI_PRO.printErrorCode();
      }
      
    }   
  
    // If the waspmote awakes due to the Events board IRQ
    if (intFlag & SENS_INT)
    {
      
      // Load the interruption flag
      Events.loadInt();
      
      // In case the interruption came from PIR
      if (pir.getInt())
      {
        USB.println(F("-----------------------------"));
        USB.println(F("Interruption from PIR"));
        USB.println(F("Presence detected"));
        USB.println(F("-----------------------------"));
      }    
      
      // Topic and message
      //topicString.cstring = (char *)"g0/mota1/temperature";
      topicString.cstring = (char *) "test/Warnings";
      snprintf((char *)payload, 100, "Presence detected", temp, humd, pres);
      
      //Format the message and send it
      int payloadlen = strlen((const char*)payload);


  
      len += MQTTSerialize_publish(buf + len, buflen - len, 0, 0, 0, 0, topicString, payload, payloadlen); //2//
  
      len += MQTTSerialize_disconnect(buf + len, buflen - len); //3//
  
      ////////////////////////////////////////////////
      // 3.2. send data
      ////////////////////////////////////////////////
      error = WIFI_PRO.send( socket_handle, buf, len);
  
      // check response
      if (error == 0)
      {
        USB.println(F("3.2. Send data OK"));
      }
      else
      {
        USB.println(F("3.2. Error calling 'send' function"));
        WIFI_PRO.printErrorCode();
      }
      
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
   
  delay(1000);  
}*/
