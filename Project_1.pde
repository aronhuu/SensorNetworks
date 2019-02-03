/*Project implementation with just one connection to the network*/

#include <WaspSensorEvent_v30.h>
#include <WaspWIFI_PRO.h>
#include <WaspFrame.h>
#include <WaspXBee802.h>
//MQTT
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

//Constant vars
const int BATTERY_THRESHOLD = 70;
const int ACC_THRESHOLD = 15;
const int DOTS_THRESHOLD = 40;

// Sockets
uint8_t socket_WiFi = SOCKET1;
uint8_t socket_802 = SOCKET0;

// TCP/IP server settings
//char HOST[]        = "10.49.1.32"; //MQTT Broker
char HOST[] = "192.168.0.160";     //Fer test
//char HOST[] = "192.168.137.187";   //Ao PC
//char HOST[] = "10.0.2.11";           //Ao Module
//char HOST[] ="172.16.30.220";       //IoT Wi
char REMOTE_PORT[] = "1883";  //MQTT without security
char LOCAL_PORT[]  = "3000";  //idk its functionallity
///////////////////////////////////////

// Variables definition, for reading data, or for determine the status of a connection
uint8_t error;              //Used for 802.15.4 and WiFi connections
uint8_t status;             //Used for WiFI connection
unsigned long previous;     //To measure the connection time
uint16_t socket_handle = 0; //Socket to TPC
uint8_t value = 0;          //To measure the PIR

//To read gateway data
float temp;
float humd;
float pres;

//Variables that are needed for the 802.15.4
int len;
unsigned char buf[200];     //Buffer to store the received package
int buflen = sizeof(buf);   //Buffer length
unsigned char payload[100]; //Payload length

//MQTT global objects: Variables for publish the message
char frameHeader1[2];
char frameHeader2[16];
//char frameType[];
char moteName[8];
int packageNumber;
int temp_rx1;
int temp_rx2;
int humd_rx1;
int humd_rx2;
char pres_rx[10];
int batteryLevel_rx;
int accX_rx;
int accY_rx;
int accZ_rx;
MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
MQTTString topicString = MQTTString_initializer;
char gtwName[] = "gateway"; //gateway moteID
int flagPIR = 0;            //To wait until the PIR sensor it stabilized
int dotController = 0;       //To print some dots via the serial communication

//PIR SENSOR position, static
pirSensorClass pir(SOCKET_1);

void setup()
{
  
  // Switch ON serial port: for debuging purposes
  USB.ON();
  USB.println(F("[SET UP] Start program"));

  // Power ON the RTC and the Accelerometer
  USB.println(F("[SET UP] Init RTC and the ACC"));
  RTC.ON(); 
  ACC.ON();  

  // Setting time [yy:mm:dd:dow:hh:mm:ss]; 2009/10/20; X, 17:35:30
  RTC.setTime("09:10:20:03:17:35:30");
  
  // Turn on the sensor board
  USB.println(F("[SET UP] Init Sensor Board"));
  Events.ON();

  //Enable the IRQs: allows to check the flags
  ACC.setFF();          //Free fall IRQ
  Events.attachInt();   //PIR IRQ
  
  // init XBee
  USB.println(F("[SET UP] Init 802.15.4"));
  xbee802.ON(socket_802);

  // Firstly, wait for PIR signal stabilization
  value = pir.readPirSensor();
  while (value == 1)
  {
    USB.println(F("[SET UP] ...wait for PIR stabilization"));
    delay(1000);
    value = pir.readPirSensor();    
  }

  //////////////////////////////////////////////////
  // Switch ON WIFI
  //////////////////////////////////////////////////
  USB.println(F("[SET UP] Init WiFi"));
  error = WIFI_PRO.ON(socket_WiFi);

  if ( error == 0 )
  {
    USB.println(F("\t[SET UP] WiFi switched ON"));
  }
  else
  {
    USB.println(F("\t[SET UP] WiFi did not initialize correctly"));
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
    USB.print(F("\t[SET UP] WiFi is connected OK"));
    USB.print(F("\t Time(ms):"));
    USB.println(millis() - previous);

    // get IP address
    error = WIFI_PRO.getIP();

    if (error == 0)
    {
      USB.print(F("\t[[SET UP] IP address: "));
      USB.println( WIFI_PRO._ip );
    }
    else
    {
      USB.println(F("\t[SET UP] getIP error"));
    }
  }
  else
  {
    USB.print(F("\t[SET UP] WiFi is connected ERROR"));
    USB.print(F("\t Time(ms):"));
    USB.println(millis() - previous);
  }

  //Set the MQTT configuration
  //data.clientID.cstring = (char*)"Edge-Node"; 
  data.keepAliveInterval = 50;      //Sending Ping to keep alive the connection: must be greather than  the data actualization
  data.cleansession = 1;            //not to close the session
}

/**
* Function that publishes a message in a given Broker (HOST and PORT)
* Every time the socket is opened and closed, this is beacuse of the adaptation of the MQTT client
* Modifies the var status, that way if something goes wrong the informations stops of beeing sended
*/
void publishMessage();


void loop()
{ 

  //Receive packages: timeout 10 sec
  error = xbee802.receivePacketTimeout( 100 );
  
  // check answer  
  if( error == 0 ) 
  { 
    USB.println("");//To start printing the information in a new line
    // Show data stored in '_payload' buffer indicated by '_length'
    USB.print(F("[802.15.4]Package Received: "));
    USB.println( xbee802._payload, xbee802._length);
   
    char msg[xbee802._length];
    for (int i = 0; i < xbee802._length; i++){
        msg[i] = xbee802._payload[i];
      }
    
    if (strstr(msg, "DataType") != NULL)
    {
      sscanf(msg, "<=>%2s#%16s#%8s#%d#STR:DataType,%02d.%02d,%02d.%02d,%8s,%d,%d,%d,%d", &frameHeader1, &frameHeader2, &moteName, &packageNumber, &temp_rx1, &temp_rx2, &humd_rx1, &humd_rx2, &pres_rx, &batteryLevel_rx, &accX_rx, &accY_rx, &accZ_rx);      //USB.println("[DEBUG] ALWAYS ENTERS HERE???");
      if (status == true){
        topicString.cstring = (char *) "test/Measurements";
        snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"t\":%02d.%02d,\"h\":%02d.%02d,\"p\":%s,\"bL\":%d,\"accX\":%d,\"accY\":%d,\"accZ\":%d}", moteName, temp_rx1, temp_rx2, humd_rx1, humd_rx2, pres_rx, batteryLevel_rx, accX_rx, accY_rx, accZ_rx);
        publishMessage();

        if (batteryLevel_rx < BATTERY_THRESHOLD){
          topicString.cstring = (char*) "test/Warnings";
          snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"bL\":1,\"FF\":0,\"PIR\":0}", moteName);
          publishMessage();
          }
      }

      //Temperature
      temp = Events.getTemperature();
      //Humidity
      humd = Events.getHumidity();
      //Pressure
      pres = Events.getPressure();
      
      // define local buffer for float to string conversion
      char temp_str[10];
      char humd_str[10];
      char pres_str[10];
      
      // use dtostrf() to convert from float to string: 
      // '1' refers to minimum width
      // '3' refers to number of decimals
      dtostrf( temp, 1, 2, temp_str);
      dtostrf( humd, 1, 2, humd_str);
      dtostrf( pres, 1, 2, pres_str);
      
      topicString.cstring = (char *) "test/Measurements";
      snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"t\":%s,\"h\":%s,\"p\":%s,\"bL\":%d,\"accX\":%d,\"accY\":%d,\"accZ\":%d}", gtwName, temp_str, humd_str, pres_str, PWR.getBatteryLevel(), ACC.getX(), ACC.getY(), ACC.getZ());
      publishMessage();

      if (PWR.getBatteryLevel() < BATTERY_THRESHOLD){
        topicString.cstring = (char*) "test/Warnings";
        snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"bL\":1,\"FF\":0,\"PIR\":0}", gtwName);
        publishMessage();
        }
    }
    else
    {
      //Check FF IRQ
      if(strstr(msg, "Presence detected") != NULL){
        sscanf(msg, "<=>%2s#%16s#%8s#%d#STR:WarningType#STR:Presence detected", &frameHeader1, &frameHeader2, &moteName, &packageNumber);
        topicString.cstring = (char*) "test/Warnings";
        snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"bL\":0,\"FF\":0,\"PIR\":1}", moteName);
        publishMessage();
        }
      else{
        //Check PIR IRQ
        if(strstr(msg, "Fall detected") != NULL){
          sscanf(msg, "<=>%2s#%16s#%8s#%d#STR:WarningType#STR:Fall detected", &frameHeader1, &frameHeader2, &moteName, &packageNumber);
          topicString.cstring = (char*) "test/Warnings";
          snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"bL\":0,\"FF\":1,\"PIR\":0}", moteName);
          publishMessage();
        }
        else{
          USB.println(F("[DEBUG] MSG doesn't match"));
        }
      }
    }
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
    if (error == 1){
      dotController++;
      USB.print(".");// Timeout error. It will inform every 
      if (dotController == DOTS_THRESHOLD) {
        USB.println("");
        dotController = 0;
        }
      }
    else{
      USB.print(F("Error receiving a packet:"));
      USB.println(error,DEC);     
      }
  }

  
  //Check PIR and FF of the gateway
  // If the waspmote awakes due to the Accelerometer IRQ
  if((ACC.getX() < ACC_THRESHOLD) && (ACC.getX() > (-1)*ACC_THRESHOLD) && (ACC.getY() < ACC_THRESHOLD) && (ACC.getY() > (-1)*ACC_THRESHOLD) && (ACC.getZ() < ACC_THRESHOLD) && (ACC.getZ() > (-1)*ACC_THRESHOLD))
  {
    USB.println("");
    USB.println("Fall detected");
    // clear interruption flag
    intFlag &= ~(ACC_INT);
    //Publish the message
    topicString.cstring = (char*) "test/Warnings";
    snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"bL\":0,\"FF\":1,\"PIR\":0}", gtwName);
    publishMessage();
  }
  
  // If the waspmote awakes due to the Events board IRQ
  if (pir.readPirSensor() == 1)
  {
    if(flagPIR == 0){
      USB.println("");
      USB.println("PIR detected");
      //Publish the message
      topicString.cstring = (char*) "test/Warnings";
      snprintf((char *)payload, 200, "{\"moteID\":\"%s\",\"bL\":0,\"FF\":0,\"PIR\":1}", gtwName);
      publishMessage();
    }
    flagPIR++;
   }
   else{
    if(flagPIR != 0) flagPIR = 0;
    }
}


void publishMessage(){
  status =  WIFI_PRO.isConnected();

  if (status == true){
    
    error = WIFI_PRO.setTCPclient( HOST, REMOTE_PORT, LOCAL_PORT);
  
    // check response
    if (error == 0)
    {
      // get socket handle (from 0 to 9)
      socket_handle = WIFI_PRO._socket_handle;
  
      //USB.print(F("\t3.1. Open TCP socket OK in handle: "));
      //USB.println(socket_handle, DEC);
    }
    else
    {
      USB.println(F("[MQTT CLIENT] Error calling 'setTCPclient' function"));
      WIFI_PRO.printErrorCode();
      status = false;
    }
  
    len = MQTTSerialize_connect(buf, buflen, &data);//1
    int payloadlen = strlen((const char*)payload);
    len += MQTTSerialize_publish(buf + len, buflen - len, 0, 0, 0, 0, topicString, payload, payloadlen); //2//
    len += MQTTSerialize_disconnect(buf + len, buflen - len); //3//
  
    error = WIFI_PRO.send( socket_handle, buf, len);
    
    // check response
    if (error == 0)
    {
      USB.println(F("[MQTT CLIENT] One Message Published"));
    }
    else
    {
      USB.println(F("[MQTT CLIENT] Error calling 'send' function"));
      WIFI_PRO.printErrorCode();
    }
  
    //Close the socket
    WIFI_PRO.closeSocket(socket_handle);
  }
}
