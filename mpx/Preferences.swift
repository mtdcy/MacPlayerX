//
//  Preferences.swift
//  mpx
//
//  Created by Chen Fang on 2019/4/14.
//  Copyright © 2019 Chen Fang. All rights reserved.
//

import Foundation

class Preferences {
    
    init() {
        // set default values
        UserDefaults.standard.register(defaults: ["openGL" : true])
    }
    
    var usingOpenGL : Bool {
        get {
            let openGL = UserDefaults.standard.bool(forKey: "openGL")
            return openGL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "openGL")
        }
    }
    
    public func show() {
        print("openGL: ", usingOpenGL)
    }
}
