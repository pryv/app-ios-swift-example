//
//  ConnectionUITests.swift
//  PryvApiSwiftKitExampleUITests
//
//  Created by Sara Alemanno on 11.06.20.
//  Copyright © 2020 Pryv. All rights reserved.
//

import XCTest
import Mocker
import PryvSwiftKit

class ConnectionListUITests: XCTestCase {
    private let defaultServiceInfoUrl = "https://reg.pryv.me/service/info"
    private let endpoint = "https://ckbc28vpd00kz1vd3s7vgiszs@testuser.pryv.me/"
    
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
               
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        sleep(1)
        
        if (app.alerts.element.exists) {
            app.alerts.element.buttons["Don’t Allow"].tap()
        }
        
        if (app.buttons["Don’t Allow"].exists) {
            app.buttons["Don’t Allow"].tap()
            app.alerts.element.buttons["OK"].tap()
        }
        
        if (app.buttons["loginButton"].exists) {
            app.buttons["loginButton"].tap()
            sleep(2)
            app.staticTexts["Username or email"].tap()
            app.typeText("testuser")
            app.staticTexts["Password"].tap()
            app.typeText("testuser")
            app.buttons["SIGN IN"].tap()
            if app.buttons["ACCEPT"].exists {
                app.buttons["ACCEPT"].tap()
            }
            sleep(5)
        }
    }

    func testConnectionViewBasicUI() {
        XCTAssert(app.staticTexts["Pryv Lab"].exists)
        XCTAssert(app.navigationBars["connectionNavBar"].exists)
        XCTAssert(app.navigationBars["connectionNavBar"].buttons["userButton"].isHittable)
        XCTAssert(app.navigationBars["connectionNavBar"].buttons["addEventButton"].isHittable)
        XCTAssert(app.tables["eventsTableView"].exists)
    }
    
    func testCreateAndDeleteSimpleEvent() {
        app.navigationBars["connectionNavBar"].buttons["addEventButton"].tap()
        app.sheets.element.buttons["Simple event"].tap()
        sleep(1)

        app.textFields["streamIdField"].tap()
        app.textFields["streamIdField"].buttons["Clear text"].tap()
        app.textFields["streamIdField"].typeText("measurements")

        app.textFields["typeField"].tap()
        app.textFields["typeField"].buttons["Clear text"].tap()
        app.textFields["typeField"].typeText("length/cm")

        app.textFields["contentField"].tap()
        app.textFields["contentField"].typeText("180")

        app.alerts.buttons["OK"].tap()
        XCTAssert(app.staticTexts["Pryv Lab"].exists)

        app.navigationBars["connectionNavBar"].buttons["addEventButton"].tap()
        app.sheets.element.buttons["Simple event"].tap()
        sleep(1)

        app.textFields["streamIdField"].tap()
        app.textFields["streamIdField"].buttons["Clear text"].tap()
        app.textFields["streamIdField"].typeText("weight")

        app.textFields["typeField"].tap()
        app.textFields["typeField"].buttons["Clear text"].tap()
        app.textFields["typeField"].typeText("mass/kg")

        app.textFields["contentField"].tap()
        app.textFields["contentField"].typeText("90")

        app.alerts.buttons["OK"].tap()
        XCTAssert(app.staticTexts["Pryv Lab"].exists)
        sleep(2)
        
        let myTable = app.tables.matching(identifier: "eventsTableView")
        let cell = myTable.cells["eventCell0"]
        
        XCTAssertEqual(cell.staticTexts["streamIdLabel"].label, "weight")
        XCTAssertEqual(cell.staticTexts["typeLabel"].label, "mass/kg")
        XCTAssertEqual(cell.staticTexts["contentLabel"].label, "90")
        XCTAssert(cell.textFields["verifiedLabel"].isHittable)
        XCTAssertFalse(cell.staticTexts["attachmentLabel"].exists)
        XCTAssertFalse(cell.images["attachmentImageView"].exists)
        
        cell.swipeLeft()
        cell.buttons["Delete"].tap()
        
        XCTAssertNotEqual(cell.staticTexts["streamIdLabel"].label, "weight")
        XCTAssertNotEqual(cell.staticTexts["typeLabel"].label, "mass/kg")
        XCTAssertNotEqual(cell.staticTexts["contentLabel"].label, "90")
        
        XCTAssertEqual(cell.staticTexts["streamIdLabel"].label, "measurements")
        XCTAssertEqual(cell.staticTexts["typeLabel"].label, "length/cm")
        XCTAssertEqual(cell.staticTexts["contentLabel"].label, "180")
    }
    
    func testCreateBadEvent() {
        let wrongField = "-----------"
        
        app.navigationBars["connectionNavBar"].buttons["addEventButton"].tap()
        app.sheets.element.buttons["Simple event"].tap()
        sleep(1)

        app.textFields["streamIdField"].tap()
        app.textFields["streamIdField"].buttons["Clear text"].tap()
        app.textFields["streamIdField"].typeText(wrongField)

        app.textFields["typeField"].tap()
        app.textFields["typeField"].buttons["Clear text"].tap()
        app.textFields["typeField"].typeText(wrongField)

        app.textFields["contentField"].tap()
        app.textFields["contentField"].typeText(wrongField)

        app.alerts.buttons["OK"].tap()
        sleep(2)
        XCTAssert(app.alerts.element.staticTexts["Error: The parameters' format is invalid."].exists)
        
        sleep(5)
        XCTAssert(app.staticTexts["Pryv Lab"].exists)
        
        let myTable = app.tables.matching(identifier: "eventsTableView")
        let cell = myTable.cells["eventCell0"]
        
        sleep(5)
        
        XCTAssertNotEqual(cell.staticTexts["streamIdLabel"].label, wrongField)
        XCTAssertNotEqual(cell.staticTexts["typeLabel"].label, wrongField)
        XCTAssertNotEqual(cell.staticTexts["contentLabel"].label, wrongField)
    }
    
    func testCreateEventWithFile() {
        app.navigationBars["connectionNavBar"].buttons["addEventButton"].tap()
        app.sheets.element.buttons["Event with attachment"].tap()
        sleep(1)
        
        app.otherElements.tables.cells["Moments"].tap()
        sleep(1)
        app.otherElements.collectionViews.element.cells.element(boundBy: 1).tap()
        sleep(10)
        
        let myTable = app.tables.matching(identifier: "eventsTableView")
        let cell = myTable.cells["eventCell0"]
        
        while (cell.staticTexts["typeLabel"].exists) { }
        
        XCTAssertEqual(cell.staticTexts["streamIdLabel"].label, "diary")
        XCTAssertFalse(cell.staticTexts["typeLabel"].exists)
        XCTAssertFalse(cell.staticTexts["contentLabel"].exists)
        XCTAssertFalse(cell.staticTexts["attachmentLabel"].exists)
        XCTAssertFalse(cell.images["attachmentImageView"].exists)
        XCTAssert(cell.textFields["verifiedLabel"].isHittable)
    }
    
    func testAddFileToEvent() {
        app.navigationBars["connectionNavBar"].buttons["addEventButton"].tap()
        app.sheets.element.buttons["Simple event"].tap()
        sleep(1)

        app.textFields["streamIdField"].tap()
        app.textFields["streamIdField"].buttons["Clear text"].tap()
        app.textFields["streamIdField"].typeText("measurements")

        app.textFields["typeField"].tap()
        app.textFields["typeField"].buttons["Clear text"].tap()
        app.textFields["typeField"].typeText("length/cm")

        app.textFields["contentField"].tap()
        app.textFields["contentField"].typeText("180")

        app.alerts.buttons["OK"].tap()
        sleep(1)
        
        let myTable = app.tables.matching(identifier: "eventsTableView")
        let cell = myTable.cells["eventCell0"]
        
        let streamId = cell.staticTexts["streamIdLabel"].label
        let type = cell.staticTexts["typeLabel"].label
        let content = cell.staticTexts["contentLabel"].label
        
        cell.buttons["addAttachmentButton"].tap()
        
        app.otherElements.tables.cells["Moments"].tap()
        sleep(1)
        app.otherElements.collectionViews.element.cells.element(boundBy: 1).tap()
        
        while (!cell.staticTexts["attachmentLabel"].exists) { }
        
        XCTAssertEqual(cell.staticTexts["streamIdLabel"].label, streamId)
        XCTAssertEqual(cell.staticTexts["typeLabel"].label, type)
        XCTAssertEqual(cell.staticTexts["contentLabel"].label, content)
        XCTAssertEqual(cell.staticTexts["attachmentLabel"].label, "image.png")
        XCTAssertFalse(cell.images["attachmentImageView"].exists)
    }
}
