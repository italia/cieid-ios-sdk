 
# CieID-iOS-sdk

CieID-iOS-sdk è un SDK per smartphone iOS sviluppato in Swift che include le funzionalità di autenticazione di "Entra con CIE". Utilizzando questo kit gli sviluppatori di applicazioni terze iOS possono integrare nella propria app l'autenticazione mediante la cartà d'identità elettronica (CIE 3.0).

# Requisiti tecnici

CieID-iOS-sdk richiede versione iOS 13.0 o successive, inoltre è necessario uno smartphone iOS con tecnologia NFC (iPhone 7 o successivo, non è compatibile con iPhone SE di prima generazione - mod 2016).

# Requisiti di integrazione

Per integrare questo kit è necessario che l'integratore sia un Service Provider federato e che integri la tecnologia abilitante al flusso di autenticazione "Entra con CIE". [Maggiori informazioni qui.](https://www.cartaidentita.interno.gov.it/CIE3.0-ManualeSP.pdf "Manuale SP").

# Come si usa

Il kit integra per il momento il solo flusso di autenticazione con reindirizzamento di seguito descritto. L'integrazione richiede pochi semplici passaggi:

 - Importazione del kit all'interno del progetto
 - Configurazione dell'URL Scheme
 - Configurazione dell'URL di un Service Provider valido all'interno del file Info.plist
 - Configurazione dello smart button Entra con CIE all'interno dello storyboard
 - Inizializzazione e presentazione della webView di autenticazione
 - Gestione dei delegati

## Flusso con reindirizzamento
Il flusso di autenticazione con reindirizzamento permette ad un Service Provider accreditato di integrare l'autenticazione Entra con CIE nella propria app iOS, demandando le operazioni di autenticazione all'app CieID. Questo flusso di autenticazione richiede che l'utente abbia l'app CieID installata sul proprio smartphone **in versione 1.2.0 o successiva.**

## Flusso interno
Non disponibile in questa versione.

## Importazione

Trascinare la folder **CieIDsdk** all'interno del progetto xCode.

## Configurazione URL Scheme

Nel flusso di autenticazione con reindirizzamento l'applicazione CieID avrà bisogno aprire l'app chiamante per potergli notificare l'avvenuta autenticazione. A tal fine è necessario configurare un URL Scheme nel progetto Xcode come segue:

Selezionare il progetto **Target**, aprire il pannello **Info** ed aprire poi il pannello **URL Types**. Compilare i campi **Identifier** e **URL Scheme** inserendo il **Bundle Identifier** dell'app, impostare poi su **none** il campo **Role**.

A seguito dell'apertura dell'app la webView dovrà ricevere un nuovo URL e proseguire la navigazione. Di seguito si riporta il metodo **openUrlContext** da importare nello **SceneDelegate** che implementa tale logica:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {

	guard let url = URLContexts.first?.url else {

		return

	}

	var urlString : String = String(url.absoluteString)
	if let httpsRange = urlString.range(of: "https://"){

	//Rimozione del prefisso dell'URL SCHEME
	let startPos = urlString.distance(from: urlString.startIndex, to: httpsRange.lowerBound)
	urlString = String(urlString.dropFirst(startPos))

	//Passaggio dell'URL alla WebView
	let response : [String:String] = ["payload": urlString]
	let NOTIFICATION_NAME : String = "RETURN_FROM_CIEID"

	NotificationCenter.default.post(name: 	Notification.Name(NOTIFICATION_NAME), object: nil, userInfo: response)

	}

}
```

## Configurazione Service Provider URL

Entrambi i flussi vengono avviati tramite l'utilizzo di una WebView, per questo motivo è necessario caricare la URL dell'ambiente di produzione della pagina web del Service Provider che integra il pulsante "Entra con CIE" all'interno del file **Info.plist**, aggiungendo un parametro chiamato **SP_URL** di tipo **String**, come mostrato nell'esempio:

```xml
    <key>SP_URL</key>
    <string>Inserisci qui l'URL dell'ambiente di produzione del Service Provider</string>
```

## Importazione del pulsante Entra con CIE

Aggiungere  nello storyboard di progetto un oggetto di tipo **UIButton** ed inserire nella voce **Class** del menù **Identity inspector** la classe che lo gestisce: **CieIDButton**. L'oggetto grafico verrà automaticamente renderizzato con il pulsante ufficiale Entra con CIE.

## Eseguire l'autenticazione

Di seguito un esempio di gestione dell'evento **TouchUpInside** per eseguire il codice necessario per inizializzare e presentare la WebView di autenticazione.

```swift
    @IBAction func  startAuthentication(_ sender: UIButton){
    
	    let cieIDAuthenticator = CieIDWKWebViewController()
	    cieIDAuthenticator.modalPresentationStyle = .fullScreen
	    cieIDAuthenticator.delegate = self
	    present(cieIDAuthenticator, animated: true, completion: nil)

	}
```

La classe chiamante dovrà essere conforme al protocollo **CieIdDelegate** come mostrato nell'esempio.

```swift
    class  ExampleViewController: UIViewController, CieIdDelegate {
    ...
    }
```

L'utente potrà navigare nella webView mostrata che lo indirizzerà sull'app CieID dove potrà eseguire l'autenticazione con la Carta di Identità Elettronica, al termine verrà nuovamente reindirizzato sull'app chiamante in cui potrà dare il consenso alla condivisione delle informazioni personali e portare al termine l'autenticazione.

Al termine dell'autenticazione verrà chiamato il delegato **CieIDAuthenticationClosedWithSuccess**. La chiamata di questo delegato proviene dalla classe **CieIDWKWebViewController**. Potrebbe rendersi necessario posticipare la chiamata di questo delegato in base alla logica di autenticazione del Service Provider.

## Gestione eventi

Il protocollo impone la gestione dei seguenti eventi mediante delegati

```swift
	func  CieIDAuthenticationClosedWithSuccess() {

		print("Authentication closed with SUCCESS")

	}
```
```swift
    func  CieIDAuthenticationCanceled() {
    
	    print("L'utente ha annullato l'operazione")
	    
	}
```
```swift

	func  CieIDAuthenticationClosedWithError(errorMessage: String) {

		print("ERROR MESSAGE: \(errorMessage)")

	}
```
 
# Licenza
Il codice sorgente è rilasciato sotto licenza BSD (codice SPDX: BSD-3-Clause).

