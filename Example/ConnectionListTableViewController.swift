//
//  ConnectionTableViewController.swift
//  PryvApiSwiftKitExample
//
//  Created by Sara Alemanno on 17.06.20.
//  Copyright © 2020 Pryv. All rights reserved.
//
import UIKit
import KeychainSwift
import PryvSwiftKit
import HealthKitBridge
import HealthKit

/// A custom cell to show the details of an event
class EventTableViewCell: UITableViewCell, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet private weak var attachmentImageView: UIImageView!
    @IBOutlet private weak var streamIdLabel: UILabel!
    @IBOutlet private weak var typeLabel: UILabel!
    @IBOutlet private weak var contentLabel: UILabel!
    @IBOutlet private weak var attachmentLabel: UILabel!
    @IBOutlet weak var addAttachmentButton: UIButton!
    
    @IBOutlet private weak var typeStackView: UIStackView!
    @IBOutlet private weak var contentStackView: UIStackView!
    @IBOutlet private weak var attachmentStackView: UIStackView!
    
    var data: (Connection?, Event)? {
        didSet {
            let (connection, event) = data!
            guard let eventId = event["id"] as? String, let streamId = event["streamId"] as? String, let type = event["type"] as? String, let content = event["content"] else { return }
            streamIdLabel.text = streamId
            
            if let data = connection?.getImagePreview(eventId: eventId), !data.isEmpty { // If the event has a picture attached, show it.
                attachmentImageView.isHidden = false
                attachmentImageView.image = UIImage(data: data)
            } else { // Otherwise, show the type of content, the actual content and the name of the file attached
                typeStackView.isHidden = false
                typeLabel.text = type
                
                // formatting the json string to make it readable
                var contentString = String(describing: content)
                
                if contentString != "<null>" {
                    contentString = contentString.replacingOccurrences(of: "=", with: ": ").condenseWhitespaces().replacingOccurrences(of: ";", with: ",\n").replacingOccurrences(of: "{", with: "").replacingOccurrences(of: ",\n }", with: "")
                    
                    contentStackView.isHidden = false
                    contentLabel.text = contentString
                }
                
                if let attachments = event["attachments"] as? [Json], let fileName = attachments.last?["fileName"] as? String {
                    attachmentStackView.isHidden = false
                    attachmentLabel.text = fileName
                }
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        attachmentImageView.image = nil
        streamIdLabel.text = nil
        typeLabel.text = nil
        contentLabel.text = nil
        attachmentLabel.text = nil
        
        attachmentImageView.isHidden = true
        attachmentStackView.isHidden = true
        contentStackView.isHidden = true
        typeStackView.isHidden = true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        attachmentImageView.accessibilityIdentifier = "attachmentImageView"
        attachmentLabel.accessibilityIdentifier = "attachmentLabel"
        streamIdLabel.accessibilityIdentifier = "streamIdLabel"
        typeLabel.accessibilityIdentifier = "typeLabel"
        contentLabel.accessibilityIdentifier = "contentLabel"
        addAttachmentButton.accessibilityIdentifier = "addAttachmentButton"
    }
    
}

class ConnectionListTableViewController: UITableViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    private let keychain = KeychainSwift()
    private var events = [Event]()
    private var connectionSocketIO: ConnectionWebSocket?
    private var healthStore = HKHealthStore()
    private let pryvStream = PryvStream(streamId: "bodyMass", type: "mass/kg") // the newly created events from this Pryv stream will be written to HealthKit as well
    private var eventId: String? = nil
    
    var appId: String?
    var connection: Connection? {
        didSet {
            let utils = Utils()
            let apiEndpoint = connection!.getApiEndpoint().lowercased()
            guard let username = utils.extractUsername(from: apiEndpoint), let (endpoint, token) = utils.extractTokenAndEndpoint(from: apiEndpoint) else {
                return
            }
            let url = "\(endpoint)\(username)?auth=\(token ?? "")"
            setRealtimeUpdates(url: url)
            getEvents()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let addEventButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addEvent))
        addEventButton.accessibilityIdentifier = "addEventButton"
        tabBarController?.navigationItem.leftBarButtonItem = addEventButton
        
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Fetching last events")
        refreshControl.addTarget(self, action: #selector(getEvents), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        tableView.allowsSelection = false
        tableView.estimatedRowHeight = 100;
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.accessibilityIdentifier = "eventsTableView"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tabBarController?.navigationItem.leftBarButtonItem?.isEnabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        tabBarController?.navigationItem.leftBarButtonItem?.isEnabled = false
    }
    
    /// Updates the list of events shown (only if an event was added)
    /// # Note
    ///     Here, we use a batch call, not the streamed version. Indeed, we are only taking the last 20 events, which does not require streaming.
    @objc private func getEvents() {
        let request = [
            [
                "method": "events.get",
                "params": Json()
            ]
        ]
        
        connection!.api(APICalls: request).then { results in
            let values = results["results"] as? [Json]
            var events = [Event]()
            values?.forEach { result in
                if let json = result as? [String: [Event]] {
                    events.append(contentsOf: json["events"] ?? [Event]())
                }
            }
            
            self.events = events
            self.refreshControl?.endRefreshing()
            self.loadViewIfNeeded()
            self.tableView.reloadData()
        }.catch { error in
            print("problem encountered when getting the events: \(error.localizedDescription)")
            self.refreshControl?.endRefreshing()
        }
    }
    
    /// Sets up the socket io connection for real time updates
    /// - Parameter apiEndpoint
    private func setRealtimeUpdates(url: String) {
        connectionSocketIO = ConnectionWebSocket(url: url)
        connectionSocketIO!.subscribe(message: .eventsChanged) { _, _ in
            self.events.removeAll()
            self.connectionSocketIO!.emit(methodId: "events.get", params: Json()) { any in
                let dataArray = any as NSArray
                let dictionary = dataArray[1] as! Json
                self.events = dictionary["events"] as! [Event]
                self.tableView.reloadData()
                self.loadViewIfNeeded()
                self.tableView.scrollToRow(at: IndexPath.init(row: 0, section: 0), at: .top, animated: true)
            }
        }
        connectionSocketIO!.connect()
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell", for: indexPath) as? EventTableViewCell, indexPath.row < events.count else { return UITableViewCell() }
        
        let event = events[indexPath.row]
        if let error = event["message"] as? String { print("Error for event at row \(indexPath.row): \(error)") ; return UITableViewCell() }
        cell.data = (connection, event)
        cell.addAttachmentButton.tag = indexPath.row
        cell.addAttachmentButton.addTarget(self, action: #selector(addAttachment), for: .touchUpInside)
        
        cell.accessibilityIdentifier = "eventCell\(indexPath.row)"
        
        return cell
    }
    
    // MARK: - Table view interactions
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            guard let eventId = events[indexPath.row]["id"] as? String else { return }
            let deleteCall: APICall = [
                "method": "events.delete",
                "params": [
                    "id": eventId
                ]
            ]
            
            self.connection?.api(APICalls: [deleteCall]).catch { error in
                print("Deletion failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Creates a new event from the fields in a `UIAlertController` and sends a `event.create` request within a callbatch
    @objc private func addEvent() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Simple event", style: .default) { _ in
            let alert = UIAlertController().newEventAlert(title: "Create an event", message: nil) { params in
                var apiCall: APICall = [
                    "method": "events.create",
                    "params": params
                ]
                
                let handleResults: [Int: (Event) -> ()] = [0: { event in
                    print("new event: \(String(describing: event))")
                }]
                
                
                if let write = self.pryvStream.hkSampleType(), self.healthStore.authorizationStatus(for: write) == .sharingAuthorized,
                    let stringContent = params["content"] as? String, let content = Double(stringContent) {
                    let sample = self.pryvStream.healthKitSample(from: content)!

                    var paramsWithTag = params
                    paramsWithTag["clientData"] = [HealthKitStream.hkClientDataId: String(describing: sample.uuid)]
                    apiCall["params"] = paramsWithTag
                    self.connection?.api(APICalls: [apiCall]).then { _ in
                        self.healthStore.save(sample) { (success, error) in
                            if !success || error != nil {
                                print("problem occurred when sending event to Health")
                            }
                        }
                    }.catch { error in
                        let innerAlert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        innerAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(innerAlert, animated: true, completion: nil)
                    }
                } else {
                    self.connection?.api(APICalls: [apiCall], handleResults: handleResults).catch { error in
                        let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true)
                    }
                }
            }
            self.present(alert, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Event with attachment", style: .default) { _ in
            self.eventId = nil
            self.selectAttachment()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true)
    }
    
    /// Adds an attachment to an existing event in the `tableView`
    /// - Parameter sender: the button that trigger this action
    @objc private func addAttachment(_ sender: UIButton) {
        let event = events[sender.tag]
        guard let id = event["id"] as? String else { return }
        eventId = id
        selectAttachment()
    }
    
    // MARK: - image picker
    
    /// Create an event with attachment or add attachment to event once an image is selected from the `UIImagePickerController`
    /// - Parameters:
    ///   - picker
    ///   - info
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        let pickedImage = info[.originalImage] as! UIImage
        guard let pickedPngData = pickedImage.pngData() else { return }
        let (_, token) = Utils().extractTokenAndEndpoint(from: connection?.getApiEndpoint() ?? "") ?? ("", "")
        let params: Json = [
            "streamIds": ["diary"],
            "type": "picture/attached"
        ]
        
        if let id = eventId {
            let media = Media(key: "file-\(UUID().uuidString)-\(String(describing: token))", filename: "image.png", data: pickedPngData, mimeType: "image/png")
            let boundary = "Boundary-\(UUID().uuidString)"
            guard let httpBody = connection?.createData(with: boundary, from: nil, and: [media]) else { return }
            connection?.addFormDataToEvent(eventId: id, boundary: boundary, httpBody: httpBody).catch { error in
                let innerAlert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                innerAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(innerAlert, animated: true, completion: nil)
            }
        } else {
            let media = Media(key: "file-\(UUID().uuidString)-\(String(describing: token))", filename: "image.png", data: pickedPngData, mimeType: "image/png")
            
            connection?.createEventWithFormData(event: params, parameters: nil, files: [media]).catch { error in
                let innerAlert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                innerAlert.addAction(UIAlertAction(title: "OK", style: .default, handler:nil))
                self.present(innerAlert, animated: true, completion: nil)
            }
        }
    }
    
    /// Opens the `UIImagePickerController` with the camera or the photo library, depending on the user's choice and camera availability
    private func selectAttachment() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let alert = UIAlertController(title: "Choose Image", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
                imagePicker.sourceType = .camera
                self.present(imagePicker, animated: true)
            }))

            alert.addAction(UIAlertAction(title: "Gallery", style: .default, handler: { _ in
                imagePicker.sourceType = .photoLibrary
                self.present(imagePicker, animated: true)
            }))

            alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))

            self.present(alert, animated: true, completion: nil)
        } else {
            imagePicker.sourceType = .photoLibrary
            self.present(imagePicker, animated: true)
        }
    }
}
