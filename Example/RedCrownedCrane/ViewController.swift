//
//  ViewController.swift
//  RedCrownedCrane
//
//  Created by forterli on 2023/3/2.
//

import UIKit
import SwiftUI
import GRDB

class ViewController: UIHostingController<TestView>  {

    override init?(coder aDecoder: NSCoder, rootView: TestView) {
        super.init(coder: aDecoder, rootView: TestView())
    }
    
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: TestView())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}

struct TestView: View {

    class ViewModel: ObservableObject {
        @Published var testItems: [TestItem] = try! dbQueue.read { db in
            let items = try TestItem.filter(Column("isDeleted") == false).fetchAll(db)
            return items
        }
        var cancellable: AnyDatabaseCancellable?
        func startObservation() {
            if cancellable == nil {
                let observation = ValueObservation.tracking { db in
                    try TestItem.filter(Column("isDeleted") == false).order(Column("modifiedAt").asc).fetchAll(db)
                }
                cancellable = observation.start(in: dbQueue) { error in
                    // Handle error
                } onChange: {[weak self] (ps: [TestItem]) in
                    self?.testItems = ps
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
                ForEach(vm.testItems, id: \.identifiable) { p in
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
        let fd = TestItem()
        try? dbQueue.write({ db in
            return try? fd.insert(db)
        })
        synaEngine.pushLocalObjectsToCloudKit(object: fd)
    }
    
    func delete(_ indexSet:IndexSet) {
        guard let index = indexSet.first else { return }
        let fd = vm.testItems[index]
        fd.isDeleted = true
        try? dbQueue.write({ db in
            return try? fd.save(db)
        })
        synaEngine.pushLocalObjectsToCloudKit(object: fd)
    }
    
    
}

struct TestView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 8", "iPhone 14 Pro"], id: \.self) { deviceName in
            TestView()
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
