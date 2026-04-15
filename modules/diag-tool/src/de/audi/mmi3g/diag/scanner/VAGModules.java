/**
 * VAG Module Database — Maps module addresses to names.
 * Based on the standard VAG diagnostic addressing used
 * by VCDS, ODIS, and all VAG diagnostic tools.
 *
 * Java 1.4 compatible.
 */
package de.audi.mmi3g.diag.scanner;

public class VAGModules {

    /** Module entry: address, name, CAN bus */
    public static final int[][] MODULE_LIST = {
        // addr, bus (0=powertrain, 1=comfort, 2=infotainment)
        {0x01, 0}, // Engine
        {0x02, 0}, // Transmission
        {0x03, 0}, // ABS/ESP
        {0x08, 1}, // HVAC
        {0x09, 1}, // Central Electrics
        {0x0F, 0}, // Airbag
        {0x15, 0}, // Airbag (alt)
        {0x17, 0}, // Instrument Cluster
        {0x19, 0}, // CAN Gateway
        {0x25, 0}, // Immobilizer
        {0x2B, 1}, // Steering Column Electronics
        {0x34, 0}, // Level Control
        {0x36, 1}, // Seat Driver
        {0x37, 1}, // Navigation
        {0x42, 1}, // Door Driver Front
        {0x44, 0}, // Steering Assist
        {0x46, 1}, // Central Comfort
        {0x47, 1}, // Sound System
        {0x4F, 1}, // Central Elect. 2
        {0x52, 1}, // Door Driver Rear
        {0x55, 2}, // Headlamp Range
        {0x56, 1}, // Radio
        {0x5F, 2}, // Information Electronics (MMI)
        {0x62, 1}, // Door Passenger Front
        {0x65, 0}, // Tire Pressure
        {0x69, 2}, // Trailer
        {0x72, 1}, // Door Passenger Rear
        {0x75, 2}, // Telematics
        {0x76, 0}, // Park Assist
        {0x77, 1}, // Telephone
        {0x7D, 1}, // Auxiliary Heater
        {0xA5, 0}, // Front Sensors
        {0xB6, 1}, // B-Pillar Driver
        {0xB7, 1}, // B-Pillar Passenger
        {0xC6, 1}, // Seat Rear Driver
        {0xCA, 1}, // Rear View Camera
        {0xCB, 1}, // Night Vision
    };

    /** Get the human-readable name for a module address. */
    public static String getModuleName(int address) {
        switch (address) {
            case 0x01: return "Engine";
            case 0x02: return "Transmission";
            case 0x03: return "ABS/ESP";
            case 0x08: return "HVAC";
            case 0x09: return "Central Electronics";
            case 0x0F: return "Airbag";
            case 0x15: return "Airbag";
            case 0x17: return "Instrument Cluster";
            case 0x19: return "CAN Gateway";
            case 0x25: return "Immobilizer";
            case 0x2B: return "Steering Column";
            case 0x34: return "Level Control";
            case 0x36: return "Seat Driver";
            case 0x37: return "Navigation";
            case 0x42: return "Door FL";
            case 0x44: return "Steering Assist";
            case 0x46: return "Central Comfort";
            case 0x47: return "Sound System";
            case 0x4F: return "Central Elect. 2";
            case 0x52: return "Door RL";
            case 0x55: return "Headlamp Range";
            case 0x56: return "Radio";
            case 0x5F: return "MMI/Infotainment";
            case 0x62: return "Door FR";
            case 0x65: return "Tire Pressure";
            case 0x69: return "Trailer";
            case 0x72: return "Door RR";
            case 0x75: return "Telematics";
            case 0x76: return "Park Assist";
            case 0x77: return "Telephone";
            case 0x7D: return "Aux Heater";
            case 0xA5: return "Front Sensors";
            case 0xB6: return "B-Pillar L";
            case 0xB7: return "B-Pillar R";
            case 0xC6: return "Seat Rear";
            case 0xCA: return "Rear Camera";
            case 0xCB: return "Night Vision";
            default:
                return "Module 0x" + Integer.toHexString(address).toUpperCase();
        }
    }

    /** Get short label for display (max 12 chars). */
    public static String getShortName(int address) {
        switch (address) {
            case 0x01: return "01-Engine";
            case 0x02: return "02-Trans";
            case 0x03: return "03-ABS";
            case 0x08: return "08-HVAC";
            case 0x09: return "09-CentElec";
            case 0x0F: return "0F-Airbag";
            case 0x15: return "15-Airbag";
            case 0x17: return "17-Cluster";
            case 0x19: return "19-Gateway";
            case 0x25: return "25-Immo";
            case 0x44: return "44-Steering";
            case 0x46: return "46-Comfort";
            case 0x47: return "47-Sound";
            case 0x5F: return "5F-MMI";
            case 0x65: return "65-TPMS";
            case 0x76: return "76-ParkAst";
            default:
                String hex = Integer.toHexString(address).toUpperCase();
                if (hex.length() < 2) hex = "0" + hex;
                return hex + "-Mod";
        }
    }
}
