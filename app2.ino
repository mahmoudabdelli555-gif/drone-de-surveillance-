#include <WiFi.h>
#include <Wire.h>
#include <MPU6050.h>
#include <DHT.h>

// Définition des broches
#define BUZZER_PIN 4
#define LED_VERTE_PIN 18
#define LED_ROUGE_PIN 19
#define DHT_PIN 15
#define MQ_PIN 34

// Broches des moteurs
#define PWMA_AVANT 25
#define PWMB_AVANT 26
#define PWMA_ARRIERE 33
#define PWMB_ARRIERE 32

// Définition des seuils
#define TEMP_MAX 40
#define HUMIDITY_MAX 80
#define GAZ_SEUIL 1950

// Objets capteurs
MPU6050 mpu;
DHT dht(DHT_PIN, DHT11);

// Variables pour la communication
WiFiServer server(1234);
String inputString = "";

// Variables pour les capteurs
float temperature, humidity;
int gazValue;
int16_t ax, ay, az, gx, gy, gz;

// Variable pour le contrôle de l'affichage
unsigned long dernierAffichage = 0;
const unsigned long intervalleAffichage = 1000; // Afficher toutes les secondes

void setup() {
  Serial.begin(115200);
  
  // Initialisation des broches
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_VERTE_PIN, OUTPUT);
  pinMode(LED_ROUGE_PIN, OUTPUT);
  pinMode(PWMA_AVANT, OUTPUT);
  pinMode(PWMB_AVANT, OUTPUT);
  pinMode(PWMA_ARRIERE, OUTPUT);
  pinMode(PWMB_ARRIERE, OUTPUT);
  
  // Éteindre tout au début
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_VERTE_PIN, LOW);
  digitalWrite(LED_ROUGE_PIN, LOW);
  analogWrite(PWMA_AVANT, 0);
  analogWrite(PWMB_AVANT, 0);
  analogWrite(PWMA_ARRIERE, 0);
  analogWrite(PWMB_ARRIERE, 0);
  
  // Initialisation capteurs
  Wire.begin();
  mpu.initialize();
  dht.begin();
  
  // Création du point d'accès
  WiFi.softAP("DroneSurveillance", "password123");
  IPAddress IP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(IP);
  
  server.begin();

  Serial.println("Système initialisé. Début de la surveillance...");
}

void loop() {
  // Lecture des capteurs
  lireCapteurs();
  
  // Vérification des seuils d'alerte
  verifierAlertes();
  
  // AFFICHAGE EN TEMPS RÉEL dans le moniteur série
  if (millis() - dernierAffichage >= intervalleAffichage) {
    afficherDonnees();
    dernierAffichage = millis();
  }
  
  // Gestion des connexions clients
  WiFiClient client = server.available();
  
  if (client) {
    Serial.println("Client connecté");
    
    while (client.connected()) {
      // Envoyer les données des capteurs
      envoyerDonnees(client);
      
      // Lire les commandes du client
      if (client.available()) {
        char c = client.read();
        if (c == '\n') {
          traiterCommande(inputString);
          inputString = "";
        } else {
          inputString += c;
        }
      }
      
      delay(100);
    }
    
    client.stop();
    Serial.println("Client déconnecté");
  }
}

void lireCapteurs() {
  // Lecture DHT11
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();
  
  // Lecture MQ2
  gazValue = analogRead(MQ_PIN);
  
  // Lecture MPU6050
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
}

// NOUVELLE FONCTION: Affichage des données dans le moniteur série
void afficherDonnees() {
  Serial.println("=== DONNÉES CAPTEURS ===");
  Serial.print("Température: ");
  Serial.print(temperature);
  Serial.println(" °C");
  
  Serial.print("Humidité: ");
  Serial.print(humidity);
  Serial.println(" %");
  
  Serial.print("Gaz: ");
  Serial.println(gazValue);
  
  Serial.print("Accéléromètre - X: ");
  Serial.print(ax);
  Serial.print(" | Y: ");
  Serial.print(ay);
  Serial.print(" | Z: ");
  Serial.println(az);
  
  Serial.print("Gyroscope - X: ");
  Serial.print(gx);
  Serial.print(" | Y: ");
  Serial.print(gy);
  Serial.print(" | Z: ");
  Serial.println(gz);
  
  // État des alertes
  if (digitalRead(LED_ROUGE_PIN) == HIGH) {
    Serial.println(">>> ALERTE: Situation anormale! <<<");
  } else {
    Serial.println("Situation normale");
  }
  
  Serial.println("========================");
}

void verifierAlertes() {
  bool situationNormale = true;
  
  if (temperature > TEMP_MAX || humidity > HUMIDITY_MAX || gazValue > GAZ_SEUIL) {
    situationNormale = false;
  }
  
  if (situationNormale) {
    digitalWrite(LED_VERTE_PIN, HIGH);
    digitalWrite(LED_ROUGE_PIN, LOW);
    digitalWrite(BUZZER_PIN, LOW);
  } else {
    digitalWrite(LED_VERTE_PIN, LOW);
    digitalWrite(LED_ROUGE_PIN, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);
  }
}

void envoyerDonnees(WiFiClient &client) {
  String data = "TEMP:" + String(temperature) + 
                ",HUM:" + String(humidity) + 
                ",GAZ:" + String(gazValue) + 
                ",AX:" + String(ax) + 
                ",AY:" + String(ay) + 
                ",AZ:" + String(az) + 
                ",GX:" + String(gx) + 
                ",GY:" + String(gy) + 
                ",GZ:" + String(gz);
  client.println(data);
}

void traiterCommande(String commande) {
  Serial.println("Commande reçue: " + commande);
  
  if (commande == "AVANT") {
    analogWrite(PWMA_AVANT, 200);
    analogWrite(PWMB_AVANT, 200);
    analogWrite(PWMA_ARRIERE, 0);
    analogWrite(PWMB_ARRIERE, 0);
  } 
  else if (commande == "ARRIERE") {
    analogWrite(PWMA_AVANT, 0);
    analogWrite(PWMB_AVANT, 0);
    analogWrite(PWMA_ARRIERE, 200);
    analogWrite(PWMB_ARRIERE, 200);
  }
  else if (commande == "GAUCHE") {
    analogWrite(PWMA_AVANT, 0);
    analogWrite(PWMB_AVANT, 200);
    analogWrite(PWMA_ARRIERE, 200);
    analogWrite(PWMB_ARRIERE, 0);
  }
  else if (commande == "DROITE") {
    analogWrite(PWMA_AVANT, 200);
    analogWrite(PWMB_AVANT, 0);
    analogWrite(PWMA_ARRIERE, 0);
    analogWrite(PWMB_ARRIERE, 200);
  }
  else if (commande == "STOP") {
    analogWrite(PWMA_AVANT, 0);
    analogWrite(PWMB_AVANT, 0);
    analogWrite(PWMA_ARRIERE, 0);
    analogWrite(PWMB_ARRIERE, 0);
  }
}