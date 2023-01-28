//
//  ContentView.swift
//  symbiose_macos_act3
//
//  Created by Jonathan Pegaz on 17/01/2023.
//

import SwiftUI

struct ContentView: View {
    @StateObject var bleController:BLEController = BLEController()
    @StateObject var bleTflite: BLEObservable = BLEObservable()
    @StateObject var myUnit = ToneOutputUnit()
    @StateObject var spheroSensorControl:SpheroSensorControl = SpheroSensorControl()
    
    @State var freq:String = ""
    
    @State var tfApp = "app pas connecté"
    @State var tfValue = "En attente de valeur ..."
    
    @State var isPlaying = false
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text(tfApp)
            Text(freq)
            Text(tfValue)
            
        }
        .padding()
        .onAppear(){
            bleController.load()
        }
        .onChange(of: bleController.bleStatus, perform: { newValue in
            bleController.addServices()
            SharedToyBox.instance.searchForBoltsNamed(["SB-808F"]) { err in
                if err == nil {
                    spheroSensorControl.load()
                    bleTflite.startScann()
                }
            }
            
        })
        .onChange(of: bleTflite.connectedPeripheral) { newValue in
            if let p = newValue {
                tfApp = p.name
                bleTflite.listen { r in
                    print(r)
                }
            }
        }
        .onChange(of: bleTflite.tflite) { newValue in
            tfValue = newValue
        }
        .onChange(of: spheroSensorControl.isShaking, perform: { newValue in
            if(newValue == true && isPlaying == false){
                myUnit.enableSpeaker()
                isPlaying = true
            }
        })
        .onChange(of: spheroSensorControl.orientation) { newValue in
            if(isPlaying == true) {
                SharedToyBox.instance.bolt!.clearMatrix()
                if(newValue > 40) {
                    myUnit.setFrequency(freq: 397)
                    self.freq = "397"
                    SharedToyBox.instance.bolt!.setMainLed(color: .green)
                }
                else if(newValue > 20) {
                    myUnit.setFrequency(freq: 375)
                    self.freq = "375"
                    SharedToyBox.instance.bolt!.setMainLed(color: .cyan)
                }
                else if (newValue > 0){
                    myUnit.setFrequency(freq: 371)
                    self.freq = "371"
                    SharedToyBox.instance.bolt!.setMainLed(color: .purple)
                }
                else if(newValue > -20) {
                    myUnit.setFrequency(freq: 355)
                    self.freq = "355"
                    SharedToyBox.instance.bolt!.setMainLed(color: .yellow)
                }
                else if(newValue > -40) {
                    myUnit.setFrequency(freq: 300)
                    self.freq = "300"
                    SharedToyBox.instance.bolt!.setMainLed(color: .orange)
                }
                else if(newValue > -60) {
                    myUnit.setFrequency(freq: 274)
                    self.freq = "274"
                    SharedToyBox.instance.bolt!.setMainLed(color: .red)
                }
                
                myUnit.setToneVolume(vol: 10)
                myUnit.setToneTime(t: 20000)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
