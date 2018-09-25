//
//  DiscoverTableTableViewController.swift
//  FoodPin
//
//  Created by Piercing on 21/9/18.
//  Copyright © 2018 AppCoda. All rights reserved.
//

import UIKit
import CloudKit

class DiscoverTableTableViewController: UITableViewController {
    
    @IBOutlet var spinner: UIActivityIndicatorView!
    
    // CKRecord object is a dictionary of key-value pairs
    // that you use fetch and save the data of you app.
    // It provides the "'object(forKey:)'" method to retrieve
    // the value of a record field (e.g. name fiels of restaur).
    var restaurants: [CKRecord] = []
    
    // NSCache es un genérico y al inicializarlo
    // debemos proporcionarle el par clave/valor
    // entre paréntesis angulares.
    var imageCache = NSCache<CKRecordID, NSURL>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spinner.hidesWhenStopped = true
        spinner.center = view.center
        tableView.addSubview(spinner)
        spinner.startAnimating()
        
        fetchRecordsFromCloud()
        
        // Pull To Refresh Control
        refreshControl = UIRefreshControl()
        refreshControl?.backgroundColor = UIColor.white
        refreshControl?.tintColor = UIColor.gray
        refreshControl?.addTarget(self, action: #selector(fetchRecordsFromCloud), for: UIControlEvents.valueChanged)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return restaurants.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // Configure the cell...
        let restaurant = restaurants[indexPath.row]
        cell.textLabel?.text = restaurant.object(forKey: "name") as? String
        
        // Set the default image
        cell.imageView?.image = UIImage(named: "photoalbum")
        
        // Check if the image is stored in cache
        if let imageFileURL = imageCache.object(forKey: restaurant.recordID) {
            
            // Fetch image from cache
            print("Get image from cache")
            if let imageData = try? Data.init(contentsOf: imageFileURL as URL) {
                cell.imageView?.image = UIImage(data: imageData)
            }
            
        } else {
            
            // Fetch Image from Cloud in background if is the firts time what it is download
            let publicDatabase = CKContainer.default().publicCloudDatabase
            let fetchRecordsImageOperation = CKFetchRecordsOperation(recordIDs: [restaurant.recordID])
            fetchRecordsImageOperation.desiredKeys = ["image"]
            fetchRecordsImageOperation.queuePriority = .veryHigh
            
            fetchRecordsImageOperation.perRecordCompletionBlock = { (record, recordID, error) -> Void in
                if let error = error {
                    print("Failed to get restaurant image: \(error.localizedDescription)")
                    return
                }
                
                if let restaurantRecord = record {
                    
                    OperationQueue.main.addOperation() {
                        
                        if let image = restaurantRecord.object(forKey: "image") {
                            let imageAsset = image as! CKAsset
                            if let imageData = try? Data.init(contentsOf: imageAsset.fileURL) {
                                cell.imageView?.image = UIImage(data: imageData)
                            }
                            
                            // Add the image URL to cache when this is downloaded for first time.
                            // This will be available when the app is starts next time.
                            self.imageCache.setObject(imageAsset.fileURL as NSURL, forKey: restaurant.recordID)
                        }
                    }
                }
            }
            
            publicDatabase.add(fetchRecordsImageOperation)
        }
        
        return cell
    }
    
    // MARK: - Cloud Kit
    
    @objc func fetchRecordsFromCloud() {
        
        // Remove existing records before refreshing
        restaurants.removeAll()
        tableView.reloadData()
        
        // Fetch data using Convenience API.
        
        // Get default container & public data base.
        let cloudContainer = CKContainer.default()
        let publicDataBase = cloudContainer.publicCloudDatabase // --> de la clase CKDatabase.
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Restaurant", predicate: predicate)
        
        
        // Create the query operation with the query.
        let queryOperation = CKQueryOperation(query: query)
        // Fields to search.
        queryOperation.desiredKeys = ["name"]
        // With high priorityo operation.
        queryOperation.queuePriority = .veryHigh
        // Maximun numbers of results.
        queryOperation.resultsLimit =  50
        // Operation in background (No thread main).
        // This is execute every time a record returned & add to array.
        queryOperation.recordFetchedBlock = { (record) -> Void in
            self.restaurants.append(record)
        }
        
        /*
         "QueryCompleteBlock" -----> proporciona un objeto de cursor para indicar si hay más
         resultados a buscar. Recordamos que usamos la propiedad resultsLimit para controlar el
         número de registros obtenidos, es posible que la aplicación no pueda recuperar todos los
         datos en un consulta única. En este caso, un objeto CKQueryCursor indica que hay más
         resultados a buscar Además, marca el punto de detención de la consulta y el punto
         de partida para recuperar los resultados restantes. Por ejemplo, digamos tienes un
         total de 100 registros de restaurantes. Para cada consulta de búsqueda, puede obtener
         un máximo de 50 registros. Después de la primera consulta, el cursor indica que
         ha obtenido el registro 1 a 50. Para su próxima consulta, debe comenzar desde el
         51 ° registro. El cursor es muy útil si necesita obtener sus datos en múltiples lotes.
          */
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if let error = error {
                print("Failed to get data from iCloud - \(error.localizedDescription)")
                return
            }
            
            // We ask the table view to reload and display the restaurants records.
            print("Successfully retrieve the data form iCloud")
            OperationQueue.main.addOperation {
                self.spinner.stopAnimating()
                self.tableView.reloadData()
                
                if let refreshControl = self.refreshControl {
                    if refreshControl.isRefreshing {
                        refreshControl.endRefreshing()
                    }
                }
            }
        }
        
        // Executy the query. Por último, llamamos al método add de
        // la clase CKDatabase para ejecutar la operación de consulta.
        publicDataBase.add(queryOperation)
    }
    
    
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
     if editingStyle == .delete {
     // Delete the row from the data source
     tableView.deleteRows(at: [indexPath], with: .fade)
     } else if editingStyle == .insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
