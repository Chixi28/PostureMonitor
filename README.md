📌 Posture Monitor App

A Flutter application for monitoring head posture using OpenEarable sensor data.
The app connects via Bluetooth, reads accelerometer/gyroscope data, and calculates pitch, roll, movement, and overall posture quality in real time.

🚀 Features

Connect to OpenEarable devices only

Live posture monitoring

Head orientation visualization

Good/neutral/warning/bad posture detection

Posture score system

Calibration function

Sitting-still reminders

Session statistics (good/warning/bad posture times)

📱 Screens

Splash Screen

Home Screen

Live Data Screen

Posture Monitor Screen

Device Connection

Settings (theme toggle)

🔧 Technology Used

Flutter (Dart)

google_fonts

Bluetooth Low Energy (BLE)

Custom posture analysis algorithms

🛠 How to Run

Clone the repository:

git clone https://github.com/<your-username>/<your-repo>.git


Install dependencies:

flutter pub get


Run the app:

flutter run

📡 OpenEarable Compatibility

This app automatically filters and connects only to devices whose names match:

OpenEarable

OE

OE_DevKit

You can change filters in bluetooth_manager.dart.

📈 Future Improvements (optional section)

Cloud sync for posture history

Daily/weekly analytics

Better movement detection

Exportable reports
