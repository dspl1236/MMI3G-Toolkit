# MMI3G Java DSI API Surface

172 DSI interface classes extracted from rom.classes (27MB) in lsd.jxe.
These are the Java APIs for communicating with every subsystem through
the DSI (Device Service Interface) framework.

## DSI Interface Classes (org.dsi.ifc.*)

Each interface has a main class and a Listener class for callbacks.

### Vehicle / Car
- DSICarClimate — HVAC climate control
- DSICarClimateExt — extended climate
- DSICarComfort — comfort features (mirrors, seats, etc.)
- DSICarComfortExt — extended comfort
- DSICarDriverAssistance — ACC, lane assist, side assist
- DSICarDriverAssistanceExt — extended driver assistance
- DSICarHybridExt — hybrid/EV vehicle extensions
- DSICarKombi — instrument cluster communication
- DSICarKombiExt — extended cluster
- DSICarLight — exterior/interior lighting
- DSICarLightExt — extended lighting
- DSICarParkingSystem — parking sensors/cameras
- DSICarParkingSystemExt — extended parking (OPS/RVC)
- DSICarSeat — seat control
- DSICarService — service intervals, oil level
- DSICarSuspensionControl — air suspension control
- DSICarSuspensionControlExt — extended suspension

### Audio / Media
- DSIAudioManagement — audio routing, volume, mute
- DSIMedia — media source control
- DSIMediaPlayer — playback control
- DSIMediaRecorder — recording
- DSISound — sound settings (bass, treble, balance)
- DSIAlbumBrowser — album art browsing
- DSIWavePlayer — wave file playback

### Tuner / Radio
- DSIAMFMTuner — AM/FM radio
- DSIDABTuner — DAB digital radio
- DSISDARSTuner — SiriusXM satellite radio
- DSITIMTuner — TIM tuner
- DSITVTuner — TV tuner
- DSITunerAnnouncement — traffic announcements

### Navigation
- DSINavigation — route planning, guidance
- DSIMapViewer — map display
- DSIMapViewerControl — map interaction
- DSIMapViewerGoogleCtrl — Google Maps integration
- DSIMapViewerLandmarkPlayer — POI display
- DSIMapViewerManeuverView — turn-by-turn
- DSIMapViewerRouteBlock — route display
- DSIMapViewerZoomEngine — zoom control
- DSIKOMONavInfo — nav info for cluster
- DSIKOMOView — cluster view
- DSITrafficRegulation — speed limits, restrictions
- DSITmc / DSITmcOnRoute — TMC traffic

### Telephony
- DSITelephone — phone calls
- DSISMS — text messaging
- DSICallLists — call history
- DSIVCardExchange — contact sharing
- DSIObexAuthentication — Bluetooth OBEX

### Connectivity
- DSIBluetooth — Bluetooth management
- DSIWLAN — WiFi
- DSIIP — IP networking
- DSIDataConnection — data connection state
- DSIDataConfiguration — data config
- DSIDialup — modem dialup
- DSIOnlineTrafficConsumer — online traffic data

### System / Core
- DSIShell — **shell command execution from Java**
- DSIPersistence — persistence database (per3)
- DSIPowerManagement — power/sleep control
- DSIStartup — startup notification
- DSIGlobal — global system state
- DSIKeyPanel — button/key input
- DSIDisplayManagement — display control
- DSIHMISync — HMI synchronization
- DSIInfotainmentRecorder — infotainment recording
- DSIDiagHMIAttribs — diagnostic attributes
- DSIProfileManager — user profiles
- DSIIconrenderer — icon rendering
- DSIBrowser — web browser
- DSIInbox — message inbox

### Security / SWDL
- DSICryptoManagerHMI — **FSC/crypto management from Java**
- DSIComponentProtection — component protection (OTP)
- DSISwdlSelection — firmware update selection
- DSISwdlDeviceInfo — device info during SWDL
- DSISwdlProgress — update progress
- DSISwdlLogging — update logging

### Speech / TTS
- DSITTS — text-to-speech
- DSIVoiceEncoder — voice encoding
- DSIPhonoConv — phonetic conversion
- DSISSS — speech dialogue system

### Data
- DSIDataDisplay / DSIDataDisplayDDP2 — data display
- DSIAddressbook — contact database
- DSIMyAudi — MyAudi services
- DSIPoiOnlineSearch — POI search
- DSIMOSTInfo — MOST bus info

## Audi Application Classes (de.audi.*)

### Core Framework (de.audi.atip.*)
- StartupManager — application lifecycle
- HMIApplication — base HMI app class
- HMIBundle — OSGi bundle management
- HMIService — service registration
- ErrorManager — error handling
- AudioConnection — audio management
- StorageManager — persistent storage
- I18NTarget — internationalization
- SDSApplication — speech dialogue
- CustomerUpdate — firmware updates

### Inter-App Services (de.audi.atip.interapp.*)
- NaviService — navigation
- MediaService — media
- PhoneService — phone
- BluetoothService — Bluetooth
- ToneService — audio tones
- OnlineService — online features
- OperatorService — operator services
- WlanService — WiFi
- CombiService — cluster
- MapService — map display
- TMCService — traffic
- TTSProviderService — TTS

### HMI Models (de.audi.atip.hmi.model.*)
- LabelModel, ListModel, ButtonModel, ChoiceModel
- RangeModel (sliders), TooltipModel
- BufferedListModel, BufferedDynamicListModel
- IconCell, TextListCell, IntegerListCell

### Hidden / Engineering
- **de.audi.tghu.redengineering.app.EngineeringApp** — "red engineering" app (separate from GEM!)
- de.audi.rome.ctrl.GoogleNavController — Google Navigation
- de.audi.rome.jni.Admin — JNI native admin access
- de.audi.myaudi.testmode — MyAudi test mode
- de.audi.tghu.diag — diagnostics
- de.audi.tghu.dsitrace.TraceConfigurator — trace config

## DSI Shell Interface

`org.dsi.ifc.shell.DSIShell` provides shell command execution
from Java code. Combined with the DSI framework, this enables
custom OSGi bundles to execute system commands.

## DSICryptoManagerHMI

`org.dsi.ifc.cryptomanagerhmi.DSICryptoManagerHMI` provides
FSC management from Java: import FSCs, query status, get public
key. This is the Java equivalent of the GEM FSC controller.
