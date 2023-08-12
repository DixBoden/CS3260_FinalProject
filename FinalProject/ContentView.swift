//
//  ContentView.swift
//  FinalProject
//
//  Created by Dixon Boden on 8/5/23.
//

import SwiftUI
import SQLite3

class Item: ObservableObject {
    let id: UUID
    @Published var shortDisc: String
    
    init(shortDisc: String) {
            self.id = UUID()
            self.shortDisc = shortDisc
        }
}

func readDatabase(items: inout Array<Item>) {
    items.removeAll()
    let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("Inventory.sqlite")
    var db: OpaquePointer?
    if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
                print("error opening database")
                return
            }
    if sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS Items (id INTEGER PRIMARY KEY AUTOINCREMENT, shortDisc VARCHAR)", nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("error creating table: \(errmsg)")
                return
            }
    let queryString = "SELECT * FROM Items"
    //statement pointer
    var stmt:OpaquePointer?
     
    //preparing the query
    if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK{
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        print("error preparing insert: \(errmsg)")
        return
    }

    //traversing through all the records
    while(sqlite3_step(stmt) == SQLITE_ROW){
        let shortDisc = String(cString: sqlite3_column_text(stmt, 1))

        //adding values to list
        items.append(Item(shortDisc: String(shortDisc)))
    }
    sqlite3_close(db)
}

func writeDatabase(items: inout Array<Item>) {
    let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("Inventory.sqlite")
    var db: OpaquePointer?
    if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
                print("error opening database")
                return
            }
    if sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS Items (id INTEGER PRIMARY KEY AUTOINCREMENT, shortDisc VARCHAR)", nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("error creating table: \(errmsg)")
                return
            }
    var stmt: OpaquePointer?
    
    if sqlite3_prepare(db, "DELETE FROM Items", -1, &stmt, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("error creating table: \(errmsg)")
                return
            }
    if sqlite3_step(stmt) != SQLITE_DONE {
        let errmsg = String(cString: sqlite3_errmsg(db)!)
        print("error creating table: \(errmsg)")
        return
    }
    var stmt2: OpaquePointer?
    //the insert query
    for item in items {
        let queryString = "INSERT INTO Items (shortDisc) VALUES (?);"
         
        //preparing the query
        if sqlite3_prepare(db, queryString, -1, &stmt2, nil) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing insert: \(errmsg)")
            return
        }
        if sqlite3_bind_text(stmt2, 1, (item.shortDisc as NSString).utf8String, -1, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error creating table: \(errmsg)")
            return
        }
        if sqlite3_step(stmt2) != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error creating table: \(errmsg)")
            return
        }
    }
    sqlite3_close(db)
}

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openURL) var openURL
    @State private var Items = Array<Item>()
    @State private var tempShortDisc: String = ""
    @State private var isPresentedAdd = false
    @State private var isPresentedEdit = false
    @State private var itemIDs:Int = 0
    var body: some View {
        NavigationView {
            VStack{
                NavigationLink(destination: RestaurantView(Items: $Items, tempShortDisc: $tempShortDisc, isPresentedAdd: $isPresentedAdd, isPresentedEdit: $isPresentedEdit, itemIDs: $itemIDs)){Text("My Restaurant List")}.background(Color.blue).buttonStyle(.borderedProminent).cornerRadius(22)
                Button("Find Place To Eat") {
                    var url = "https://www.google.com/maps/search/food"
                        if (Items.count != 0) {
                            let randomInt = Int.random(in: 0..<Items.count)
                            let restaurantAddress = Items[randomInt].shortDisc.replacingOccurrences(of: " ", with: "+")
                            url = "https://www.google.com/maps/search/" + restaurantAddress + "+restaurant"
                        }
                               openURL(URL(string: url)!)
                }.background(Color.green).buttonStyle(.borderedProminent).cornerRadius(22)
                }.onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        readDatabase(items: &Items)
                    } else if newPhase == .inactive {
                        writeDatabase(items: &Items)
                    }
                }
            }
        }
    }
    
    struct RestaurantView: View {
        @Environment(\.scenePhase) var scenePhase
        @Binding var Items: Array<Item>
        @Binding var tempShortDisc: String
        @Binding var isPresentedAdd: Bool
        @Binding var isPresentedEdit: Bool
        @Binding var itemIDs:Int
        @StateObject private var itemTester = Item(shortDisc: "Tester")
        var body: some View {
            NavigationView {
                List {
                    ForEach(Array(Items.enumerated()), id: \.1.id) {
                        i, k in
                        Button {
                            tempShortDisc = k.shortDisc
                            itemIDs = i
                            isPresentedEdit = true
                        } label: {
                            VStack (alignment: .leading) {
                                Text(k.shortDisc)
                                    .font(.title3)
                                
                            }
                        }.sheet(isPresented: $isPresentedEdit) {
                            EditView(isPresented: $isPresentedEdit, tempShortDisc:  $tempShortDisc, Items: $Items, itemTester: itemTester, itemID: $itemIDs)
                        }
                    }.onDelete { indexSet in
                        Items.remove(atOffsets: indexSet)
                    }            }
                .navigationBarTitle("My Restaurant List", displayMode: .inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add Restaurant") {
                            isPresentedAdd = true
                        }
                        .sheet(isPresented: $isPresentedAdd) {
                            AddView(isPresented: $isPresentedAdd, tempShortDisc:  $tempShortDisc, Items: $Items)
                        }
                    }
                }.onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        readDatabase(items: &Items)
                    } else if newPhase == .inactive {
                        writeDatabase(items: &Items)
                    }
                }
            }
    }
    
    struct AddView: View {
        @Environment(\.scenePhase) var scenePhase
        @Binding var isPresented: Bool
        @Binding var tempShortDisc: String
        @Binding var Items: Array<Item>
        var body: some View {
            NavigationView {
                VStack{
                    HStack {
                        Text("Restaurant: ")
                        TextField("", text: $tempShortDisc)
                            .accessibilityLabel("addShortDescription")
                            .accessibilityValue(tempShortDisc)
                    }
                }
                .navigationBarTitle("Add New Restaurant", displayMode: .inline)
                .padding()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if(tempShortDisc != ""){
                                let tempItem = Item(shortDisc: tempShortDisc)
                                Items.append(tempItem)
                            }
                            tempShortDisc = ""
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            tempShortDisc = ""
                            isPresented = false
                        }
                    }
                }.onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        readDatabase(items: &Items)
                    } else if newPhase == .inactive {
                        writeDatabase(items: &Items)
                    }
                }
            }
        }
    }
}
        
    struct EditView: View {
        @Environment(\.scenePhase) var scenePhase
        @Binding var isPresented: Bool
        @Binding var tempShortDisc: String
        @Binding var Items: Array<Item>
        @ObservedObject var itemTester: Item
        @Binding var itemID: Int
        var body: some View {
            NavigationView {
                VStack{
                    HStack {
                        Text("Restaurant: ")
                        TextField("", text: $tempShortDisc)
                            .accessibilityLabel("editShortDescription")
                            .accessibilityValue(tempShortDisc)
                    }
                }
                .navigationBarTitle("Edit Restaurant", displayMode: .inline)
                .padding()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if(tempShortDisc != "" ){
                                Items[itemID].shortDisc = tempShortDisc
                                itemTester.shortDisc = tempShortDisc
                            }
                            tempShortDisc = ""
                            isPresented = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            tempShortDisc = ""
                            isPresented = false
                        }
                    }
                }.onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        readDatabase(items: &Items)
                    } else if newPhase == .inactive {
                        writeDatabase(items: &Items)
                    }
                }
            }
        }
    }
            
            struct ContentView_Previews: PreviewProvider {
                static var previews: some View {
                    ContentView()
                }
            }
