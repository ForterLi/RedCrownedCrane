//
//  ContentView.swift
//  RedCrownedCrane-Demo
//
//  Created by forterli on 2023/3/24.
//

import SwiftUI
import GRDB
import CloudKit
import RedCrownedCrane

struct ContentView: View {

    class ViewModel: ObservableObject {
        @Published var demoItems: [DemoItem] = try! dbQueue.read { db in
            let items = try DemoItem.filter(Column("isDeleted") == false).fetchAll(db)
            return items
        }
        var cancellable: AnyDatabaseCancellable?
        func startObservation() {
            if cancellable == nil {
                let observation = ValueObservation.tracking { db in
                    try DemoItem.filter(Column("isDeleted") == false).order(Column("modifiedAt").asc).fetchAll(db)
                }
                cancellable = observation.start(in: dbQueue) { error in
                    // Handle error
                } onChange: {[weak self] (ps: [DemoItem]) in
                    self?.demoItems = ps
                }
            }
        }

        init() {
            
        }
    }
    
    @StateObject var vm = ViewModel()

    var body: some View {
        NavigationView {
            List {
                ForEach(vm.demoItems, id: \.identifiable) { p in
                    Text("name:\(p.name)")
                }.onDelete { index in
                    self.delete(index)
                }
            }
            .navigationBarItems(trailing: Button(action: {
                add()
            }, label: {
                Image(systemName:"plus")
            }))
        }.navigationViewStyle(.stack)
        .onAppear{
            vm.startObservation()
        }
    }
    
    
    func add() {
        let fd = DemoItem()
        try? dbQueue.write({ db in
            return try? fd.insert(db)
        })
        synaEngine.pushLocalObjectsToCloudKit(object: fd)
    }
    
    func delete(_ indexSet:IndexSet) {
        guard let index = indexSet.first else { return }
        let fd = vm.demoItems[index]
        fd.isDeleted = true
        try? dbQueue.write({ db in
            return try? fd.save(db)
        })
        synaEngine.pushLocalObjectsToCloudKit(object: fd)
    }
    
    
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
