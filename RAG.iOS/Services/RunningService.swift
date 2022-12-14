//
//  RunningManager.swift
//  RAG.iOS
//
//  Created by Bjorn Derudder on 19/04/2021.
//

import Foundation
import CoreLocation

enum RunningSystemState {
    case Initializing
    case Ready
    case Running
    case Stopped
}

class RunningService: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var currentDistance: Double = 0.0
    @Published var currentTime: Double = 0.01
    @Published var currentPace: (Int, Int) = (0,0)
    @Published var state: RunningSystemState = .Stopped
    
    let locationManager = CLLocationManager()
    var lastSavedLocation: CLLocation? = nil
    
    var timer: Timer? = nil
    var saveDistanceAndTimeTimer: Timer? = nil
    var calculatePaceTimer: Timer? = nil

    var doubleFormat = ".2"
    
    var timingList = FIFOList()
    
    func startRunning() {
        if (state == .Ready) {
            if (isRunningAvailable()) {
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                    self.currentTime += 0.01
                }
                self.saveDistanceAndTimeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    self.saveDistanceAndTime()
                }
                self.calculatePaceTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                    self.calculatePace()
                }
                updateState(newState: .Running)
                print("Started measuring")
            } else {
                print("running is not available")
            }
        }
    }
    
    func initSystems() {
        performChecks()
        updateState(newState: .Initializing)
        print("Initializing the running systems")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        print("Start updating the location")
        locationManager.startUpdatingLocation()
    }
    
    private func updateState(newState: RunningSystemState) {
        state = newState
    }
    
    func stopRunning() {
        print("Systems stopped")
        locationManager.stopUpdatingLocation()
        print(currentDistance)
        
        // reset all values
        currentDistance = 0.0
        currentTime = 0.0
        timingList.wipe()
        
        print(currentTime)
        
        // invalidate all the timers
        timer?.invalidate()
        saveDistanceAndTimeTimer?.invalidate()
        calculatePaceTimer?.invalidate()
        
        print("Stopped measuring")
        updateState(newState: .Stopped)
    }
    
    var locationsToReceiveBeforeReady = 2
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else {
            print("coordinates are empty")
            print("Performing checks again")
            _ = self.performChecks()
            return
        }
        
        if (state == .Initializing) {
            if (locationsToReceiveBeforeReady == 0) {
                print("Systems armed and ready for use")
                updateState(newState: .Ready)
                locationsToReceiveBeforeReady = 2
                return
            }
            locationsToReceiveBeforeReady -= 1
            return
        }
        
        if (state == .Running) {
            print("updated location")
            updatePosition(location: CLLocation(latitude: locValue.latitude, longitude: locValue.longitude))
        }
    }
    
    func saveDistanceAndTime() {
        timingList.add(key: currentTime, value: currentDistance)
    }
    
    func calculatePace() {
        if (state == .Running && currentDistance > 0 && currentTime > 0) {
            // from the timing list take the first item
            guard let firstTiming = timingList.content.first else {
                return
            }
            let secondsPerKilometer = (currentTime - firstTiming.key) / (currentDistance-firstTiming.value) * 1000
            currentPace = secondsToHoursMinutesSeconds(seconds: Int(round(secondsPerKilometer)))
        }
    }
    
    func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int) {
        return ((seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    func updatePosition(location: CLLocation) {
        
        // if location is nil then just update the last saved location
        guard let lastSaved = lastSavedLocation else {
            lastSavedLocation = location
            return
        }
        
        updateDistance(oldLocation: lastSaved, newLocation: location)
        
    }
    
    func updateDistance(oldLocation: CLLocation, newLocation: CLLocation) {
        let resultInMeters = oldLocation.distance(from: newLocation)
        lastSavedLocation = newLocation
        currentDistance += resultInMeters
    }
    
    func isRunningAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled();
    }
    
    func performChecks() -> Bool {
        if (locationManager.authorizationStatus == .authorizedAlways) {
            print("permission for take off is granted")
            if (CLLocationManager.locationServicesEnabled()) {
                print("location services are enabled")
            }
        } else {
            print("permission for take off is not yet granted")
            print("asking permission")
            self.locationManager.requestAlwaysAuthorization()
        }
        return false
    }
    
}

class FIFOList {
    var lenght = 10;
    var content = Array<ListItem>()
    
    func add(key: Double, value:Double) {
        if (content.count < lenght) {
            content.append(ListItem(key: key, value: value))
        }
        else {
            var newArray = Array<ListItem>()
            for item in content.dropFirst() {
                newArray.append(item)
            }
            newArray.append(ListItem(key: key, value: value))
            content = newArray
        }
    }
    
    func wipe() {
        content = Array<ListItem>()
    }
    
    class ListItem {
        var key: Double
        var value: Double
        
        init(key: Double, value: Double) {
            self.key = key
            self.value = value
        }
    }
}
