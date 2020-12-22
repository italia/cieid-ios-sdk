# CieID-ios-sdk

CieID-ios-sdk è un SDK iOS sviluppato in Swift che include le funzionalità di autenticazione di "Entra con CIE". Utilizzando questo kit, gli sviluppatori di applicazioni terze iOS possono integrare l'autenticazione mediante la cartà d'identità elettronica (CIE 3.0).

# Requisiti tecnici

CieID-ios-sdk è compatibile dalla versione iOS 13.0 o successive. Necessità di Iphone dotati di NFC e di una connessione ad internet.

# Requisiti di integrazione

CieID-ios-sdk necessita che il fornitore del servizio digitale sia un Service Provider federato e che integri la tecnologia abilitante al flusso di autenticazione "Entra con CIE". [Maggiori informazioni qui.](https://www.cartaidentita.interno.gov.it/CIE3.0-ManualeSP.pdf "Manuale SP")

# Come si usa

Nel kit è presente un'applicazione di esempio, che mostra come integrare il flusso facilmente. La gestione degli errori è demandata all'applicazione integrante.

## Flusso con reindirizzamento
Permette di completare il flusso di autenticazione mediante l'applicazione "CieID" presente sull'App Store.

# Licenza
Il codice sorgente è rilasciato sotto licenza BSD (codice SPDX: BSD-3-Clause).
