import SwiftUI

// MARK: - EtiquetarFlow
//
// Trilha Etiquetar: tag virgem -> busca item -> vincula. A tela real e a
// LiquidVincularTagView (dois passos: achar o serial, ler a tag nova). O gate
// de conexao do leitor vive dentro da propria view: o passo de scan usa o
// ScanEngine quando ha leitor e cai pro NeedsReaderPrompt quando esta off.

struct EtiquetarFlow: View {
    var body: some View {
        LiquidVincularTagView()
    }
}
