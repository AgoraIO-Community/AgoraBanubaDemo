import UIKit

public class EffectsService {
  
  static let shared = EffectsService()
  
  let fm = FileManager.default
  let path = Bundle.main.bundlePath + "/effects"
  let externalEffectsPath = AppDelegate.documentsPath + "/effects"
  
  func loadEffects(path: String) -> [String] {
    do {
      return try fm.contentsOfDirectory(atPath: path).filter {content in
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: path + "/" + content, isDirectory: &isDir)
      }
    } catch {
      print("\(error)")
      return []
    }
  }
}
