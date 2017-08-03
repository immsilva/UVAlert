//
//  ViewController.swift
//  UV Alert
//
//  Created by Ivo  Silva on 23/05/17.
//  Copyright © 2017 immsilva. All rights reserved.
//

import UIKit
import CoreLocation
import UserNotifications

extension UIViewController {
    
    func showToast(message : String) {
        
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 75, y: self.view.frame.size.height-100, width: 150, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
}
extension String {
    
    /// Percent escapes values to be added to a URL query as specified in RFC 3986
    ///
    /// This percent-escapes all characters besides the alphanumeric character set and "-", ".", "_", and "~".
    ///
    /// http://www.ietf.org/rfc/rfc3986.txt
    ///
    /// :returns: Returns percent-escaped string.
    
    func addingPercentEncodingForURLQueryValue() -> String? {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }
    
}

extension Dictionary {
    
    /// Build string representation of HTTP parameter dictionary of keys and objects
    ///
    /// This percent escapes in compliance with RFC 3986
    ///
    /// http://www.ietf.org/rfc/rfc3986.txt
    ///
    /// :returns: String representation in the form of key1=value1&key2=value2 where the keys and values are percent escaped
    
    func stringFromHttpParameters() -> String {
        let parameterArray = self.map { (key, value) -> String in
            let percentEscapedKey = (key as! String).addingPercentEncodingForURLQueryValue()!
            let percentEscapedValue = (value as! String).addingPercentEncodingForURLQueryValue()!
            return "\(percentEscapedKey)=\(percentEscapedValue)"
        }
        
        return parameterArray.joined(separator: "&")
    }
    
}
extension URLSession {
    //this needs to be adapted
    //check this for help to get the results from the request-https://stackoverflow.com/questions/27531195/return-multiple-values-from-a-function-in-swift
    //TODO: the method self.dataTask(with: url) has to be self.dataTask(with: request) which is a HTTP request
    func synchronousDataTask(url: String, parameters: [String: AnyObject]) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let parameterString = parameters.stringFromHttpParameters()
        let requestURL = URL(string:"\(url)?\(parameterString)")!
        
        //let semaphore = DispatchSemaphore(value: 0)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: request) {
            data = $0
            response = $1
            error = $2
            
            semaphore.signal()
        }
        dataTask.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        return (data, response, error)
    }
}

//Converts string to JSON
extension String {
    var parseJSONString: Any? {
        let data = self.data(using: String.Encoding.utf8, allowLossyConversion: false)
        guard let jsonData = data else { return nil }
        do { return try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) }
        catch { return nil }
    }
}

extension DispatchQueue {
    
    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            background?()
            if let completion = completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                    completion()
                })
            }
        }
    }
}

//CHecks if date is between two HH:MM
extension Date
{
    
    func dateAt(hours: Int, minutes: Int) -> Date
    {
        let calendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)!
        
        //get the month/day/year componentsfor today's date.
        
        
        var date_components = calendar.components(
            [NSCalendar.Unit.year,
             NSCalendar.Unit.month,
             NSCalendar.Unit.day],
            from: self)
        
        //Create an NSDate for the specified time today.
        date_components.hour = hours
        date_components.minute = minutes
        date_components.second = 0
        
        let newDate = calendar.date(from: date_components)!
        return newDate
    }
}

class ViewController: UIViewController, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    let apikey = "NiDthNJAAJhvqAeb0L4NB7CPB6YG302t"
    //location manager
    let manager = CLLocationManager()
    var location = CLLocation()
    var placeKey = String()
    var uvIndex = -1
    var uvIndexText = String()
    var currentWeather = String()
    var currentWeatherIconNumber = Int()
    var currentTemperature = String()
    var currentLocationCity = String()
    var currentLocationCountryCode = String()
    var currentConditionsText = String()
    var checkDate = Date()
    var countGetIndex = 0
    
    @IBOutlet var uvIndexLabel: UILabel!
    @IBOutlet var currentConditionsLabel: UILabel!
    
    @IBOutlet var moreInfoButton: UIButton!
    @IBOutlet var checkUVLevelButton: UIButton!
    let datePicker = UIDatePicker()
    @IBOutlet weak var scheduleButton: UIButton!
    
    @IBOutlet var scrollView: UIScrollView!
    var refreshControl: UIRefreshControl!
    
    //What to do when location changes
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations[0] //get most recent position
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest //best location accuracy
        
        manager.requestAlwaysAuthorization() //request for always get location
        
        manager.startUpdatingLocation()
        
        //get notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: {didAllow, error in })
        UNUserNotificationCenter.current().delegate = self
        
        
        //run code in the next second
        let date = Date().addingTimeInterval(0.1)
        let timer = Timer(fireAt: date, interval: 0.5, target: self, selector: #selector(getUVIndex), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
        
        /*
        //notify in 5 seconds - START
        let dateNotification = Date().addingTimeInterval(5)
        let timerNotification = Timer(fireAt: dateNotification, interval: 20, target: self, selector: #selector(sendNotification), userInfo: nil, repeats: true)
        RunLoop.main.add(timerNotification, forMode: RunLoopMode.commonModes)
        //set notification badge number to zero
        UIApplication.shared.applicationIconBadgeNumber = 0
        //Notification - END
        */
        
        
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refresh), for: UIControlEvents.valueChanged)
        scrollView.refreshControl = refreshControl
        //scrollView.addSubview(refreshControl) // not required when using UITableViewController
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func refresh(sender:AnyObject) {
        // Code to refresh table view
        getUVIndex(waitDialog: false)
        refreshControl.endRefreshing()
    }
    
    func updateUI(){
        self.uvIndexLabel.text = "UV level: " + String( self.uvIndex) + " (" + self.uvIndexText + ")"
        //self.uvIndexLabel.text
        self.setCurrentConditionsLabel()
        //sendNotification()
        scheduleNotifications()
    }
    

    
    func scheduleNotifications() {
        let now = Date()
        let six_thirty_today = now.dateAt(hours: 6, minutes: 30)
        let eight_thirty_today = now.dateAt(hours: 8, minutes: 30)
        
        if now >= six_thirty_today && now <= eight_thirty_today
        {
            print("Sending notification because time is between 6:30 and 8:30")
           
            // create a corresponding local notification
            let notification = UILocalNotification()
            notification.fireDate = NSDate(timeIntervalSinceNow: 10) as Date //fire notification in 10 seconds
            notification.alertTitle = "UV level for "+self.currentLocationCity
            //notification.alertBody = "Enjoyed your lunch? Don't forget to track your expenses!"
            
            //set body of notification
            if(self.uvIndex>=0 && self.uvIndex<=2){
                notification.alertBody = String(self.uvIndex)+" (Low)"
            }else if(self.uvIndex>=3 && self.uvIndex<=5){
                notification.alertBody = String(self.uvIndex)+" (Moderate)"
            }else if(self.uvIndex>=6 && self.uvIndex<=7){
                notification.alertBody = String(self.uvIndex)+" (High)"
            }else if(self.uvIndex>=8 && self.uvIndex<=10){
                notification.alertBody = String(self.uvIndex)+" (Very High)"
            }else if(self.uvIndex>=11){
                notification.alertBody = String(self.uvIndex)+" (Extreme)"
            }
            notification.alertAction = "Check UV level"
            notification.repeatInterval = NSCalendar.Unit.day    // Repeats the notifications daily
            notification.applicationIconBadgeNumber=1
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
   
    /*
    // Notification implementation (not working)
    func sendNotification(){
        
        print("Sending notification")
        
        // when background job finished, do something in main thread
        //check if it is between hours we want
        let content = UNMutableNotificationContent()
        content.setValue(true, forKey: "shouldAlwaysAlertWhileAppIsForeground")
        content.title = "UV level for "+self.currentLocationCity
        if(self.uvIndex>=0 && self.uvIndex<=2){
            content.subtitle = String(self.uvIndex)+" (Low)"
        }else if(self.uvIndex>=3 && self.uvIndex<=5){
            content.subtitle = String(self.uvIndex)+" (Moderate)"
        }else if(self.uvIndex>=6 && self.uvIndex<=7){
            content.subtitle = String(self.uvIndex)+" (High)"
        }else if(self.uvIndex>=8 && self.uvIndex<=10){
            content.subtitle = String(self.uvIndex)+" (Very High)"
        }else if(self.uvIndex>=11){
            content.subtitle = String(self.uvIndex)+" (Extreme)"
        }
        
        // content.body = "This is the body"
        content.badge = 1
        //var date = DateComponents()
        //let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        
        //display the notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "UVAlert", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        
    }
    */
    
    
    @IBAction func showMoreInfoButton(_ sender: UIButton) {
        // create the alert
        let alert = UIAlertController(title: uvIndexText+" UV Index", message: getUVIndexDescription(uvIndex: uvIndex), preferredStyle: UIAlertControllerStyle.alert)
        
        // add an action (button)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        
        // show the alert
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func scheduleButton(_ sender: Any) {
        
    }
    
    
    @objc func getUVIndex(waitDialog: Bool){
        var auxWaitDialog = waitDialog
        
        if countGetIndex == 0 {
            auxWaitDialog = true
        }
        countGetIndex += 1
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        print(lat)
        print(lon)
        
        var queryParameters = [String : AnyObject]()
        queryParameters["apikey"]=apikey as AnyObject
        queryParameters["q"]=String(lat)+","+String(lon) as AnyObject
        //q=41.531022,-8.615531
        
        if(auxWaitDialog){
            //wait dialog
            let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
            
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
            loadingIndicator.startAnimating();
            
            alert.view.addSubview(loadingIndicator)
            present(alert, animated: true, completion: nil)
            //end - wait dialog
        }
        
        do{
            var task = sendRequest(url: "http://dataservice.accuweather.com/locations/v1/cities/geoposition/search", parameters: queryParameters) { (data, response, error) in
                
                print(String(describing: response)+"\n")
                print("data: "+String(describing: data)+"\n")
                if String(describing: response).range(of:"status code: 503") != nil{
                    print("Error getting position")
                    //update label HERE
                    DispatchQueue.main.async(execute: { () -> Void in
                        //label.text = "\(responseString)"
                        //self.uvIndexLabel.text = "(No more API requests)"
                        self.uvIndexText = "(No more API requests)"
                        
                        //self.uvIndexDescriptionLabel.text = self.getUVIndexDescription(uvIndex: self.uvIndex)
                        self.moreInfoButton.isHidden = false //show button
                        if(auxWaitDialog){
                            //dismiss alert
                            self.dismiss(animated: false, completion: nil)
                        }
                        
                    })
                }else{
                    //here we can process the request
                    
                    if let data = data {
                        let jsonString = String(data: data, encoding: String.Encoding.utf8)
                        let json: AnyObject? = jsonString?.parseJSONString as AnyObject
                        //debug
                        //print("Parsed JSON: "+String(describing: json!))
                        //print("json[Key]: "+String(describing: json!["Key"]))
                        self.placeKey = json!["Key"] as! String
                        self.currentLocationCity = json!["LocalizedName"] as! String
                        let country = json!["Country"] as AnyObject
                        self.currentLocationCountryCode = (country["ID"] as? String)!
                        
                        //print(string) //JSONSerialization
                    }
                    //print("data: "+String(describing: data)+"\n")
                    print(String(describing: response)+"\n")
                    print(String(describing: error)+"\n")
                    
                    var queryParametersUVReq = [String : AnyObject]()
                    queryParametersUVReq["apikey"]=self.apikey as AnyObject
                    queryParametersUVReq["details"]="true" as AnyObject
                    let urlCurrentConditions = "http://dataservice.accuweather.com/currentconditions/v1/"+self.placeKey
                    print("URL: "+String(urlCurrentConditions))
                    _ = self.sendRequest(url: urlCurrentConditions, parameters: queryParametersUVReq) { (data, response, error) in
                        
                        if let data = data {
                            let jsonString = String(data: data, encoding: String.Encoding.utf8)
                            let json: AnyObject? = jsonString?.parseJSONString as AnyObject
                            print("Parsed JSON FULL conditions: "+String(describing: json!))
                            //TODO: GET UV index from JSON file
                            //TODO: How to get the UVIndex value from the first position of the JsonArray
                            if let array = json as? [[String: Any]] {
                                if let firstObject = array.first {
                                    // access individual object in array
                                    //firstObject.valueForKey()
                                    for (key, value) in firstObject {
                                        print("\(key) -> \(value)")
                                    }
                                    self.uvIndex = (firstObject["UVIndex"] as? Int)!
                                    print("json[UVIndex]: "+String(describing: self.uvIndex))
                                    self.uvIndexText = (firstObject["UVIndexText"] as? String)!
                                    self.currentWeather = (firstObject["WeatherText"] as? String)!
                                    self.currentWeatherIconNumber = (firstObject["WeatherIcon"] as? Int)!
                                    //self.currentTemperature =
                                    let temp = firstObject["Temperature"] as AnyObject
                                    let metric = temp["Metric"] as AnyObject
                                    let celsiusTemp = (metric["Value"] as? Int)!
                                    self.currentTemperature = String(celsiusTemp)
                                    print("json[UVIndexText]: "+String(describing: self.uvIndexText))
                                    print("json[WeatherText]: "+String(describing: self.currentWeather))
                                    print("json[TEMPP]: "+String(describing: celsiusTemp))
                                    
                                    //update label HERE
                                    DispatchQueue.main.async(execute: { () -> Void in
                                        //label.text = "\(responseString)"
                                        self.uvIndexLabel.text = "UV level: " + String( self.uvIndex) + " (" + self.uvIndexText + ")"
                                        self.setCurrentConditionsLabel()
                                        //self.uvIndexDescriptionLabel.lineBreakMode = .byWordWrapping
                                        //self.uvIndexDescriptionLabel.numberOfLines = 0
                                        
                                        //self.uvIndexDescriptionLabel.text = self.getUVIndexDescription(uvIndex: self.uvIndex)
                                        self.moreInfoButton.isHidden = false //show button
                                        if(auxWaitDialog){
                                            //dismiss alert
                                            self.dismiss(animated: false, completion: nil)
                                        }
                                        
                                    })
                                    
                                }
                            }
                            //print("json[UVIndexText]: "+String(describing: json!["UVIndexText"]))
                        }
                        //print("data: "+String(describing: data)+"\n")
                        //print(String(describing: response)+"\n") //debug
                        //print(String(describing: error)+"\n") //debug
                    }
                }
            }
        } catch {
            print(error)
        }
        
        //Update values here
        
        //showToast(message: "Lat="+String(location.coordinate.latitude)+" Lon="+String(location.coordinate.longitude))
    }
    
    @objc func getUVIndexBackground(waitDialog: Bool){
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        print(lat)
        print(lon)
        
        var queryParameters = [String : AnyObject]()
        queryParameters["apikey"]=apikey as AnyObject
        queryParameters["q"]=String(lat)+","+String(lon) as AnyObject
        //q=41.531022,-8.615531
        do{
            var task = sendRequest(url: "http://dataservice.accuweather.com/locations/v1/cities/geoposition/search", parameters: queryParameters) { (data, response, error) in
                print(String(describing: response)+"\n")
                if let data = data {
                    let jsonString = String(data: data, encoding: String.Encoding.utf8)
                    let json: AnyObject? = jsonString?.parseJSONString as AnyObject
                    //debug
                    //print("Parsed JSON: "+String(describing: json!))
                    //print("json[Key]: "+String(describing: json!["Key"]))
                    self.placeKey = json!["Key"] as! String
                    self.currentLocationCity = json!["LocalizedName"] as! String
                    let country = json!["Country"] as AnyObject
                    self.currentLocationCountryCode = (country["ID"] as? String)!
                    //print(string) //JSONSerialization
                }
                //print("data: "+String(describing: data)+"\n")
                print(String(describing: response)+"\n")
                print(String(describing: error)+"\n")
                
                var queryParametersUVReq = [String : AnyObject]()
                queryParametersUVReq["apikey"]=self.apikey as AnyObject
                queryParametersUVReq["details"]="true" as AnyObject
                let urlCurrentConditions = "http://dataservice.accuweather.com/currentconditions/v1/"+self.placeKey
                print("URL: "+String(urlCurrentConditions))
                _ = self.sendRequest(url: urlCurrentConditions, parameters: queryParametersUVReq) { (data, response, error) in
                    
                    if let data = data {
                        let jsonString = String(data: data, encoding: String.Encoding.utf8)
                        let json: AnyObject? = jsonString?.parseJSONString as AnyObject
                        print("Parsed JSON FULL conditions: "+String(describing: json!))
                        //TODO: GET UV index from JSON file
                        //TODO: How to get the UVIndex value from the first position of the JsonArray
                        if let array = json as? [[String: Any]] {
                            if let firstObject = array.first {
                                // access individual object in array
                                //firstObject.valueForKey()
                                for (key, value) in firstObject {
                                    print("\(key) -> \(value)")
                                }
                                do{
                                self.uvIndex = (firstObject["UVIndex"] as? Int)!
                                print("json[UVIndex]: "+String(describing: self.uvIndex))
                                self.uvIndexText = (firstObject["UVIndexText"] as? String)!
                                self.currentWeather = (firstObject["WeatherText"] as? String)!
                                self.currentWeatherIconNumber = (firstObject["WeatherIcon"] as? Int)!
                                //self.currentTemperature =
                                let temp = firstObject["Temperature"] as AnyObject!
                                let metric = temp?["Metric"] as AnyObject!
                                let celsiusTemp = (metric?["Value"] as? Int)!
                                self.currentTemperature = String(celsiusTemp)
                                print("json[UVIndexText]: "+String(describing: self.uvIndexText))
                                print("json[WeatherText]: "+String(describing: self.currentWeather))
                                print("json[TEMPP]: "+String(describing: celsiusTemp))
                            } catch {
                                print(error)
                            }
                                
                            }
                        }
                        //print("json[UVIndexText]: "+String(describing: json!["UVIndexText"]))
                    }
                    //print("data: "+String(describing: data)+"\n")
                    //print(String(describing: response)+"\n") //debug
                    //print(String(describing: error)+"\n") //debug
                }
            }
        } catch {
            print(error)
        }
        //Update values here
    }
    
    
    func setCurrentConditionsLabel()  {
        var weather = String()
        switch currentWeatherIconNumber {
        case 1:
            weather="☀"
        case 2:
            weather="🌤"
        case 3:
            weather="⛅"
        case 4:
            weather="🌤"
        case 5:
            weather="🌤"
        case 6:
            weather="🌥"
        case 7:
            weather="☁"
        case 8:
            weather="☁"
        case 11:
            weather="🌫"
        case 12:
            weather="🌧"
        case 13:
            weather="🌦"
        case 14:
            weather="🌦"
        case 15:
            weather="⛈"
        case 16:
            weather="⛈"
        case 17:
            weather="⛈"
        case 18:
            weather="🌧"
        case 19:
            weather="🌧"
        case 20:
            weather="🌦"
        case 21:
            weather="🌦"
        case 22:
            weather="🌧"
        case 23:
            weather="🌧"
        case 24:
            weather="❄"
        case 25:
            weather="🌨"
        case 26:
            weather="🌧"
        case 29:
            weather="🌧"
        case 30:
            weather="🔥"
        case 31:
            weather="❄"
        case 32:
            weather="🌬"
        case 33:
            weather="🌕"
        case 34:
            weather="🌗"
        case 35:
            weather="🌔"
        case 36:
            weather="🌔"
        case 37:
            weather="🌫"
        case 38:
            weather="☁"
        case 39:
            weather="🌧"
        case 40:
            weather="🌧"
        case 41:
            weather="⛈"
        case 42:
            weather="⛈"
        case 43:
            weather="🌘"
        default:
            weather="🌍"
        }
        self.currentConditionsLabel.text = String(self.currentTemperature)+"ºC "+weather+self.currentLocationCity+", "+self.currentLocationCountryCode
    }
    
    func sendRequest(url: String, parameters: [String: AnyObject], completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionTask {
        let parameterString = parameters.stringFromHttpParameters()
        let requestURL = URL(string:"\(url)?\(parameterString)")!
        
        //let semaphore = DispatchSemaphore(value: 0)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
        //semaphore.signal()
        task.resume()
        //_ = semaphore.wait(timeout: .distantFuture)
        return task
    }
    
    
    
    func getUVIndexDescription(uvIndex: Int) -> String {
        switch uvIndex {
        case -1:
            return "Please check the UV levels."
        case 0:
            return "A UV Index reading of 0 to 2 means low danger from the sun's UV rays for the average person.\n - Wear sunglasses on bright days.\n - If you burn easily, cover up and use broad spectrum SPF 30+ sunscreen.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 1:
            return "A UV Index reading of 0 to 2 means low danger from the sun's UV rays for the average person.\n - Wear sunglasses on bright days.\n - If you burn easily, cover up and use broad spectrum SPF 30+ sunscreen.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 2:
            return "A UV Index reading of 0 to 2 means low danger from the sun's UV rays for the average person.\n - Wear sunglasses on bright days.\n - If you burn easily, cover up and use broad spectrum SPF 30+ sunscreen.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 3:
            return "A UV Index reading of 3 to 5 means moderate risk of harm from unprotected sun exposure.\n - Stay in shade near midday when the sun is strongest.\n - If outdoors, wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 4:
            return "A UV Index reading of 3 to 5 means moderate risk of harm from unprotected sun exposure.\n - Stay in shade near midday when the sun is strongest.\n - If outdoors, wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 5:
            return "A UV Index reading of 3 to 5 means moderate risk of harm from unprotected sun exposure.\n - Stay in shade near midday when the sun is strongest.\n - If outdoors, wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 6:
            return "A UV Index reading of 6 to 7 means high risk of harm from unprotected sun exposure. Protection against skin and eye damage is needed.\n - Reduce time in the sun between 10 a.m. and 4 p.m.\n - If outdoors, seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating. - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 7:
            return "A UV Index reading of 6 to 7 means high risk of harm from unprotected sun exposure. Protection against skin and eye damage is needed.\n - Reduce time in the sun between 10 a.m. and 4 p.m.\n - If outdoors, seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating. - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
            
        case 8:
            return "A UV Index reading of 8 to 10 means very high risk of harm from unprotected sun exposure. Take extra precautions because unprotected skin and eyes will be damaged and can burn quickly.\n - Minimize sun exposure between 10 a.m. and 4 p.m.\n - If outdoors, seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 9:
            return "A UV Index reading of 8 to 10 means very high risk of harm from unprotected sun exposure. Take extra precautions because unprotected skin and eyes will be damaged and can burn quickly.\n - Minimize sun exposure between 10 a.m. and 4 p.m.\n - If outdoors, seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 10:
            return "A UV Index reading of 8 to 10 means very high risk of harm from unprotected sun exposure. Take extra precautions because unprotected skin and eyes will be damaged and can burn quickly.\n - Minimize sun exposure between 10 a.m. and 4 p.m.\n - If outdoors, seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        case 11:
            return "A UV Index reading of 11 or more means extreme risk of harm from unprotected sun exposure. Take all precautions because unprotected skin and eyes can burn in minutes.\n - Try to avoid sun exposure between 10 a.m. and 4 p.m.\n - If outdoors, seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        default:
            return "A UV Index reading of 11 or more means extreme risk of harm from unprotected sun exposure. Take all precautions because unprotected skin and eyes can burn in minutes.\n - Try to avoid sun exposure between 10 a.m. and 4 p.m.\n - If outdoors, seek shade and wear protective clothing, a wide-brimmed hat, and UV-blocking sunglasses.\n - Generously apply broad spectrum SPF 30+ sunscreen every 2 hours, even on cloudy days, and after swimming or sweating.\n - Watch out for bright surfaces, like sand, water and snow, which reflect UV and increase exposure."
        }
        
    }
    
    
}

