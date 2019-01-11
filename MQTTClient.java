import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;

//import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

public class MQTTClient implements MqttCallback {

	MqttClient client;
	
	public MQTTClient() {}
	
	
	public void doDemo() {
	    try {
	        client = new MqttClient("tcp://127.0.0.1:1883", "Sending");
	        client.connect();
	        client.setCallback(this);
	        client.subscribe("test");
	        //MqttMessage message = new MqttMessage();
	        //message.setPayload("A single message from my computer fff"
	        //        .getBytes());
	        //client.publish("test", message);
	    } catch (MqttException e) {
	        e.printStackTrace();
	    }
	}
	
	@Override
	public void connectionLost(Throwable cause) {
	    // TODO Auto-generated method stub
	
	}
	
	@Override
	public void messageArrived(String topic, MqttMessage message) throws Exception {
	 System.out.println("Meassage arrived: " + message);
	 publishInfo(new URL("http://api.thingspeak.com/update?apikey=57DMCLT0NQXN1UVY&field1=21.1&field2=100&field3=75.1&field4=1&field5=51"));
	}
	
	public void publishInfo(URL url) {
	
		try {
			HttpURLConnection conn = (HttpURLConnection) url.openConnection();
			conn.setRequestMethod("GET");
			//conn.setRequestProperty("Accept", "application/json");
			conn.setRequestProperty("Accept", "text/xml");
			if(conn.getResponseCode()!=200) {
				throw new RuntimeException("Failed : HTPP error code: " + conn.getResponseCode());
			}
			conn.disconnect();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}
	
	@Override
	public void deliveryComplete(IMqttDeliveryToken token) {
	    // TODO Auto-generated method stub
	
	}
	
	
	public static void main(String[] args) {
	    new MQTTClient().doDemo();
	}

}