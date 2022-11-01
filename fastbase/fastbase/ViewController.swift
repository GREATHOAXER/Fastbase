//
//  ViewController.swift
//  fastbase
//
//  Created by Hyung Seo Han on 2022/10/31.
//

import UIKit
import CryptoKit
import AuthenticationServices
import FirebaseAuth


class ViewController: UIViewController {
    
    fileprivate var currentNonce: String?
    
    lazy var loginBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Sign with apple", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.backgroundColor = .black
        button.layer.cornerRadius = 15.0
        button.addTarget(self, action: #selector(login(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy var logoutBtn: UIButton = {
        let button = UIButton()
        button.setTitle("Sign out", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(logout(_:)), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .systemBackground
        view.addSubview(loginBtn)
        view.addSubview(logoutBtn)
        logoutBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoutBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoutBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            logoutBtn.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        loginBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loginBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginBtn.bottomAnchor.constraint(equalTo: logoutBtn.topAnchor, constant: -20),
            loginBtn.widthAnchor.constraint(equalToConstant: 356),
            loginBtn.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func randomNonceString(length: Int = 32) -> String{
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map{_ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess{
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            randoms.forEach{ random in
                if remainingLength == 0{
                    return
                }
                if random < charset.count{
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
    
    @objc func login(_ sender: Any){
        let currentUser = Auth.auth().currentUser
        print(currentUser?.uid)
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController  = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    @objc func logout(_ sender: Any){
        let currentUser = Auth.auth().currentUser
        currentUser?.getIDTokenForcingRefresh(true){idToken, error in
            if let error = error{
                print(error)
                return
            }
        }
        
        let firebaseAuth = Auth.auth()
        do{
            try firebaseAuth.signOut()
        }catch let signOutError as NSError{
            print("Error signing out: %@", signOutError)
            return
        }
        print("Log out 성공")
    }
}

extension ViewController: ASAuthorizationControllerDelegate{
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else{
                fatalError("Invalid state : A login callback was received, but no login request was sent")
            }
            guard let appleIDToken = appleIDCredential.identityToken else{
                print("Unable to fetch identitly token.")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else{
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            //Initialize a Firebase credential.
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
            
            //Sign in with Firebase.
            Auth.auth().signIn(with: credential) {(authResult, error) in
                if error != nil{
                    print(error!.localizedDescription)
                    return
                }
            }
            let currentUser = Auth.auth().currentUser
            currentUser?.getIDTokenForcingRefresh(true){idToken, error in
                if let error = error{
                    print(error)
                    return
                }
                print(idToken!)
                print("---------------------")
                print(idTokenString)
            }
            
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple errored: \(error)")
    }
}

extension ViewController: ASAuthorizationControllerPresentationContextProviding{
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}
