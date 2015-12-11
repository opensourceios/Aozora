//
//  NotificationViewController.swift
//  Aozora
//
//  Created by Paul Chavarria Podoliako on 9/7/15.
//  Copyright (c) 2015 AnyTap. All rights reserved.
//

import Foundation
import ANCommonKit
import ANParseKit

protocol NotificationsViewControllerDelegate: class {
    func notificationsViewControllerClearedAllNotifications()
}

class NotificationsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    var fetchController = FetchController()
    weak var delegate: NotificationsViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchNotifications()
        title = "Notifications"
        tableView.estimatedRowHeight = 112.0
        tableView.rowHeight = UITableViewAutomaticDimension
        
        let clearAll = UIBarButtonItem(title: "Read all", style: UIBarButtonItemStyle.Plain, target: self, action: "clearAllPressed:")
        navigationItem.rightBarButtonItem = clearAll
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "fetchNotifications", name: "newNotification", object: nil)
    }
    
    deinit {
        fetchController.tableView = nil
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParentViewController() {
            let unreadNotifications = fetchController.dataSource.filter { (notification: PFObject) -> Bool in
                let notification = notification as! Notification
                return !notification.readBy.contains(User.currentUser()!)
            }
            
            if unreadNotifications.count == 0 {
                delegate?.notificationsViewControllerClearedAllNotifications()
            }
        } else {
            tableView.userInteractionEnabled = true
        }
    }
    
    func fetchNotifications() {
        let query = Notification.query()!
        query.includeKey("lastTriggeredBy")
        query.includeKey("triggeredBy")
        query.includeKey("subscribers")
        query.includeKey("owner")
        query.includeKey("readBy")
        query.whereKey("subscribers", containedIn: [User.currentUser()!])
        query.orderByDescending("lastUpdatedAt")
        fetchController.configureWith(self, query: query, queryDelegate:self, tableView: tableView, limit: 50)
    }
    
    func clearAllPressed(sender: AnyObject) {
        let unreadNotifications = fetchController.dataSource.filter { (notification: PFObject) -> Bool in
            
            let notification = notification as! Notification
            guard !notification.readBy.contains(User.currentUser()!) else {
                return false
            }
            
            notification.addUniqueObject(User.currentUser()!, forKey: "readBy")
            return true
        }
        
        if unreadNotifications.count != 0 {
            PFObject.saveAllInBackground(unreadNotifications)
            tableView.reloadData()
        }
    }
    
    @IBAction func dismissViewController(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}

extension NotificationsViewController: UITableViewDataSource {
   
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchController.dataCount()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let notification = fetchController.objectAtIndex(indexPath.row) as! Notification
        
        let cell = tableView.dequeueReusableCellWithIdentifier("NotificationCell") as! BasicTableCell
        

        if notification.lastTriggeredBy.isTheCurrentUser() {
            var selectedUser = notification.lastTriggeredBy
            for user in notification.triggeredBy where !user.isTheCurrentUser() {
                selectedUser = user
                break
            }
            cell.titleimageView.setImageWithPFFile(selectedUser.avatarThumb!)
        } else {
            cell.titleimageView.setImageWithPFFile(notification.lastTriggeredBy.avatarThumb!)
        }
        

        if notification.owner.isTheCurrentUser() {
            cell.titleLabel.text = notification.messageOwner
        } else if notification.lastTriggeredBy.isTheCurrentUser() {
            cell.titleLabel.text = notification.previousMessage ?? notification.message
        } else {
            cell.titleLabel.text = notification.message
        }
        
        if notification.readBy.contains(User.currentUser()!) {
            cell.contentView.backgroundColor = UIColor.backgroundWhite()
        } else {
            cell.contentView.backgroundColor = UIColor.backgroundDarker()
        }
        
        cell.subtitleLabel.text = (notification.lastUpdatedAt ?? notification.updatedAt!).timeAgo()
        cell.layoutIfNeeded()
        return cell
    }
}

extension NotificationsViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // Open
        let notification = fetchController.objectAtIndex(indexPath.row) as! Notification
        
        if !notification.readBy.contains(User.currentUser()!) {
            // The actual save of this change happens on `handleNotification`
            notification.addUniqueObject(User.currentUser()!, forKey: "readBy")
            tableView.reloadData()
        }
        
        // Temporal fix to prevent opening the notification twice
        tableView.userInteractionEnabled = false
        NotificationsController.handleNotification(notification.objectId!, objectClass: notification.targetClass, objectId: notification.targetID)
    }
}

extension NotificationsViewController: FetchControllerQueryDelegate {
    func queriesForSkip(skip skip: Int) -> [PFQuery]? {
        return nil
    }
    func processResult(result result: [PFObject], dataSource: [PFObject]) -> [PFObject] {
        let filtered = result.filter({ (object: PFObject) -> Bool in
            let notification = object as! Notification
            return notification.triggeredBy.count > 1 || (notification.triggeredBy.count == 1 && !notification.triggeredBy.last!.isTheCurrentUser())
        })
        return filtered
    }
}

extension NotificationsViewController: FetchControllerDelegate {
    func didFetchFor(skip skip: Int) {
        
    }
}

extension NotificationsViewController: UINavigationBarDelegate {
    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.TopAttached
    }
}