export type TrainingTrackId = 'web' | 'ios'

export type TrainingChapter = {
  id: string
  title: string
  summary: string
  result: string
  steps: string[]
  timecode: string | null
}

export type TrainingTroubleshooting = {
  id: string
  title: string
  symptom: string
  likelyCause: string
  safeAction: string
  escalateWhen: string
}

export type TrainingTrack = {
  id: TrainingTrackId
  title: string
  eyebrow: string
  purpose: string
  audience: string
  durationLabel: string
  dependencyLabel: string
  chapters: TrainingChapter[]
  troubleshooting: TrainingTroubleshooting[]
}

export const TRAINING_CONTENT_VERSION = '0.1.0-draft'
export const TRAINING_LAST_REVIEWED = '17/07/2026'

const webChapters: TrainingChapter[] = [
  {
    id: 'web-login',
    title: 'Entrar com segurança',
    summary: 'Acessar o MMD com o usuário real sem expor senha, token ou dados pessoais.',
    result: 'Dashboard aberto com a sessão do Marcelo.',
    steps: [
      'Abrir a tela de login',
      'Entrar sem compartilhar a senha na gravação',
      'Confirmar o nome do usuário no sistema',
    ],
    timecode: null,
  },
  {
    id: 'web-dashboard',
    title: 'Ler o painel operacional',
    summary: 'Entender disponíveis, em campo, manutenção, prontidão e alertas antes de agir.',
    result: 'Marcelo identifica o que exige atenção naquele momento.',
    steps: [
      'Ler o ring de prontidão',
      'Conferir os números de estoque',
      'Abrir o próximo Evento com risco',
    ],
    timecode: null,
  },
  {
    id: 'web-catalog',
    title: 'Encontrar item e unidade',
    summary: 'Diferenciar o tipo de equipamento da unidade física rastreável.',
    result: 'Item e unidade correta localizados pelo código MMD.',
    steps: ['Buscar um item', 'Abrir o detalhe', 'Comparar item, unidade, serial e condição'],
    timecode: null,
  },
  {
    id: 'web-event',
    title: 'Abrir o Evento de treinamento',
    summary: 'Revisar ficha, cliente, datas e contexto do ciclo isolado.',
    result: '`Treinamento · Marcelo` aberto sem misturar dados de cliente.',
    steps: ['Abrir Eventos', 'Localizar o código TRN-MARCELO', 'Conferir ficha e status'],
    timecode: null,
  },
  {
    id: 'web-packing',
    title: 'Revisar o packing',
    summary: 'Entender quantidade pedida, cobertura própria e aluguel avulso.',
    result: 'Packing inicial 4/5 reconhecido como incompleto.',
    steps: ['Ler cada linha', 'Comparar necessário e alocado', 'Identificar a unidade faltante'],
    timecode: null,
  },
  {
    id: 'web-allocation',
    title: 'Alocar unidades',
    summary: 'Escolher uma unidade disponível e interpretar conflito ou bloqueio.',
    result: 'Packing passa de 4/5 para 5/5 sem alocação duplicada.',
    steps: [
      'Abrir o seletor de unidade',
      'Conferir status e conflito',
      'Alocar a unidade de conclusão',
    ],
    timecode: null,
  },
  {
    id: 'web-gate',
    title: 'Entender o bloqueio de saída',
    summary: 'Ver por que o sistema impede check-out incompleto e o que corrige o problema.',
    result: 'Marcelo distingue bloqueio real de alerta informativo.',
    steps: [
      'Tentar a saída no estado incompleto',
      'Ler o motivo',
      'Completar a cobertura e conferir o novo estado',
    ],
    timecode: null,
  },
  {
    id: 'web-checkout',
    title: 'Fazer o check-out',
    summary: 'Confirmar a saída somente depois que o Evento estiver pronto.',
    result: 'Evento em campo e unidades atualizadas no backend.',
    steps: [
      'Confirmar status do Evento',
      'Revisar o plano de saída',
      'Executar e aguardar a confirmação',
    ],
    timecode: null,
  },
  {
    id: 'web-dashboard-after',
    title: 'Conferir o reflexo no painel',
    summary: 'Validar que a saída mudou o estado operacional sem corte escondendo atualização.',
    result: 'Dashboard mostra o Evento em campo e menos unidades disponíveis.',
    steps: ['Voltar ao Dashboard', 'Atualizar a leitura', 'Comparar antes e depois'],
    timecode: null,
  },
  {
    id: 'web-return',
    title: 'Registrar o retorno',
    summary: 'Tratar uma unidade OK, uma com problema e uma não devolvida.',
    result: 'Unidade OK disponível, problema em manutenção e pendência aberta.',
    steps: [
      'Marcar retorno OK',
      'Registrar problema com observação',
      'Criar pendência para unidade não devolvida',
    ],
    timecode: null,
  },
  {
    id: 'web-qr',
    title: 'Usar o QR seguro',
    summary: 'Abrir a etiqueta e a ficha pública sem expor RFID, valor ou histórico interno.',
    result: 'Ficha pública correta aberta pelo código da unidade.',
    steps: [
      'Abrir QR codes',
      'Localizar a unidade',
      'Conferir os campos permitidos na página pública',
    ],
    timecode: null,
  },
  {
    id: 'web-audit',
    title: 'Conferir a auditoria',
    summary: 'Ver quem fez, quando fez e qual movimentação foi registrada.',
    result: 'Saída e retorno rastreáveis no histórico.',
    steps: [
      'Abrir o histórico do Evento',
      'Conferir operador e horário',
      'Relacionar movimentação e unidade',
    ],
    timecode: null,
  },
  {
    id: 'web-close',
    title: 'Fechar o ciclo',
    summary: 'Recapitular o caminho sem depender de termos técnicos.',
    result: 'Marcelo repete o fluxo Evento, packing, saída, retorno e auditoria.',
    steps: [
      'Revisar os cinco estados do ciclo',
      'Conferir pendências reais',
      'Encerrar somente com o sistema consistente',
    ],
    timecode: null,
  },
]

const iosChapters: TrainingChapter[] = [
  {
    id: 'ios-install',
    title: 'Instalar no iPhone',
    summary: 'Fazer a primeira instalação assistida pelo Xcode com personal signing.',
    result: 'App assinado e aberto no iPhone físico do Marcelo.',
    steps: [
      'Conectar e confiar no iPhone',
      'Selecionar aparelho, Team e bundle id',
      'Instalar e confiar no perfil quando solicitado',
    ],
    timecode: null,
  },
  {
    id: 'ios-login',
    title: 'Entrar e conferir o ambiente',
    summary: 'Abrir uma sessão real sem mostrar chave, token ou senha.',
    result: 'App autenticado no mesmo backend do Web.',
    steps: [
      'Entrar com o usuário real',
      'Confirmar conexão com o backend',
      'Manter credenciais fora da gravação',
    ],
    timecode: null,
  },
  {
    id: 'ios-runtime',
    title: 'Provar o modo Zebra SDK',
    summary: 'Desativar simulação e verificar que o runtime não está em fallback.',
    result: 'Configuração mostra `Zebra SDK` no aparelho real.',
    steps: [
      'Abrir Configuração',
      'Desativar leitor simulado',
      'Parar se aparecer Simulado ou fallback',
    ],
    timecode: null,
  },
  {
    id: 'ios-pair',
    title: 'Conectar o RFD40',
    summary: 'Preparar, descobrir e conectar o leitor físico conforme a documentação oficial.',
    result: 'RFD40 real conectado e identificado no app.',
    steps: [
      'Conferir carga e modo do leitor',
      'Autorizar Bluetooth',
      'Descobrir e conectar o RFD40',
    ],
    timecode: null,
  },
  {
    id: 'ios-tags',
    title: 'Ler tags conhecidas e desconhecidas',
    summary: 'Ler pelo menos cinco tags reais sem descartar EPC não reconhecido.',
    result: 'Tag conhecida resolve uma unidade e tag desconhecida vira pendência tratável.',
    steps: [
      'Ler a tag conhecida',
      'Ler as outras tags em lote',
      'Registrar a tag sem vínculo para tratamento',
    ],
    timecode: null,
  },
  {
    id: 'ios-packing',
    title: 'Conferir o packing em campo',
    summary: 'Usar o lote de leituras para conferir o Evento de treinamento.',
    result: 'Cinco unidades conferidas contra o mesmo packing do Web.',
    steps: ['Abrir o Evento', 'Iniciar a conferência', 'Resolver faltas e leituras extras'],
    timecode: null,
  },
  {
    id: 'ios-checkout',
    title: 'Fazer a saída e provar persistência',
    summary: 'Executar o check-out no iPhone usando a mesma regra operacional do Web.',
    result: 'Saída registrada e visível no backend e no Web.',
    steps: ['Conferir prontidão', 'Executar o check-out', 'Abrir o Web e provar a atualização'],
    timecode: null,
  },
  {
    id: 'ios-return',
    title: 'Registrar retorno e problema',
    summary: 'Devolver unidade OK e abrir problema ou pendência sem baixa silenciosa.',
    result: 'Estados e auditoria persistidos no backend real.',
    steps: [
      'Registrar retorno OK',
      'Registrar problema com observação',
      'Conferir a pendência no Web',
    ],
    timecode: null,
  },
  {
    id: 'ios-fallback',
    title: 'Usar QR e recuperar erros',
    summary: 'Continuar com QR quando RFID não estiver disponível e recuperar sessão ou conexão.',
    result: 'Operação segue de forma segura sem fingir leitura RFID.',
    steps: [
      'Ler QR pela câmera',
      'Reconectar leitor quando necessário',
      'Entrar novamente se a sessão expirar',
    ],
    timecode: null,
  },
]

const webTroubleshooting: TrainingTroubleshooting[] = [
  {
    id: 'web-login-denied',
    title: 'Login recusado ou sessão expirada',
    symptom: 'A tela volta para o login ou informa acesso interno.',
    likelyCause: 'Senha incorreta, sessão expirada ou usuário sem acesso.',
    safeAction: 'Confirmar o usuário, entrar novamente e não redefinir senha por tentativa.',
    escalateWhen: 'O login correto falhar duas vezes ou o usuário não existir.',
  },
  {
    id: 'web-backend',
    title: 'Web sem acesso ao backend',
    symptom: 'Dados não carregam ou a tela mostra erro de conexão.',
    likelyCause: 'Internet indisponível, ambiente incorreto ou Supabase fora do ar.',
    safeAction: 'Testar a internet, recarregar uma vez e preservar a tela de erro.',
    escalateWhen: 'Outras páginas também falharem ou o erro persistir após reconexão.',
  },
  {
    id: 'web-checkout-blocked',
    title: 'Evento bloqueado para saída',
    symptom: 'O botão de check-out não libera a operação.',
    likelyCause: 'Packing incompleto, conflito ativo ou status incorreto.',
    safeAction:
      'Ler o motivo, completar as unidades e resolver conflitos sem usar override por reflexo.',
    escalateWhen: 'O Evento estiver 100% coberto e o bloqueio continuar.',
  },
  {
    id: 'web-return-pending',
    title: 'Retorno criou pendência',
    symptom: 'Uma unidade não volta para disponível ao finalizar.',
    likelyCause: 'Foi marcada como não devolvida ou com problema.',
    safeAction: 'Abrir a pendência, conferir a observação e resolver somente com evidência física.',
    escalateWhen: 'A unidade aparecer em outro Evento ou o destino correto estiver incerto.',
  },
  {
    id: 'web-qr',
    title: 'QR não abre',
    symptom: 'A câmera não reconhece ou a página pública não carrega.',
    likelyCause: 'Etiqueta danificada, código incorreto ou internet indisponível.',
    safeAction:
      'Digitar o código MMD na busca interna e gerar outra etiqueta se a unidade conferir.',
    escalateWhen: 'O código apontar para outra unidade ou não existir no catálogo.',
  },
]

const iosTroubleshooting: TrainingTroubleshooting[] = [
  {
    id: 'ios-expired',
    title: 'App gratuito expirou',
    symptom: 'O iPhone não abre o app instalado pelo Xcode.',
    likelyCause: 'A assinatura gratuita expirou e exige nova instalação.',
    safeAction: 'Conectar o iPhone ao Mac e repetir a instalação assistida pelo Xcode.',
    escalateWhen: 'O signing não reconhecer o Apple ID ou o aparelho.',
  },
  {
    id: 'ios-device-missing',
    title: 'iPhone não aparece no Xcode',
    symptom: 'O aparelho não aparece como destino de build.',
    likelyCause: 'Cabo, confiança no computador ou modo desenvolvedor pendente.',
    safeAction: 'Reconectar o cabo, desbloquear o iPhone e aceitar a confiança nos dois lados.',
    escalateWhen: 'O Finder também não reconhecer o aparelho.',
  },
  {
    id: 'ios-profile',
    title: 'Perfil de desenvolvedor não confiável',
    symptom: 'O iOS impede a primeira abertura do app.',
    likelyCause: 'O perfil do personal signing ainda não foi autorizado.',
    safeAction:
      'Abrir Ajustes, localizar o perfil do desenvolvedor e confiar somente no Apple ID usado na instalação.',
    escalateWhen: 'O perfil exibido não for o mesmo usado no Xcode.',
  },
  {
    id: 'ios-reader-missing',
    title: 'RFD40 não aparece',
    symptom: 'A busca não encontra o leitor físico.',
    likelyCause: 'Leitor desligado, sem carga, em modo incorreto ou Bluetooth sem permissão.',
    safeAction: 'Conferir carga, modo e permissão, depois reiniciar uma busca.',
    escalateWhen: 'Outro aparelho também não encontrar o RFD40.',
  },
  {
    id: 'ios-fallback-mode',
    title: 'App mostra Simulado ou fallback',
    symptom: 'A configuração não mostra `Zebra SDK`.',
    likelyCause: 'Build sem o framework Zebra ou simulação ainda ativa.',
    safeAction: 'Parar a operação RFID e usar QR como fallback identificado.',
    escalateWhen: 'O build de device deveria conter o SDK e continua em fallback.',
  },
  {
    id: 'ios-disconnect',
    title: 'Leitor desconectou durante a leitura',
    symptom: 'O contador para e o app mostra leitor desconectado.',
    likelyCause: 'Perda de Bluetooth, bateria ou distância.',
    safeAction:
      'Parar o lote, aproximar o leitor, reconectar e iniciar outra leitura identificada.',
    escalateWhen: 'A desconexão se repetir com carga e distância normais.',
  },
  {
    id: 'ios-known-not-resolved',
    title: 'Tag conhecida não resolve a unidade',
    symptom: 'Uma tag cadastrada aparece como não reconhecida.',
    likelyCause: 'EPC diferente, vínculo incorreto ou ambiente errado.',
    safeAction: 'Preservar o EPC lido e conferir o vínculo pelo código MMD no Web.',
    escalateWhen: 'O EPC estiver ligado a outra unidade ou houver duplicidade.',
  },
  {
    id: 'ios-unknown-tag',
    title: 'Tag desconhecida',
    symptom: 'A leitura aparece sem unidade correspondente.',
    likelyCause: 'Tag nova, não cadastrada ou de outro patrimônio.',
    safeAction: 'Registrar para tratamento e não associar por adivinhação.',
    escalateWhen: 'Não for possível identificar fisicamente o equipamento correto.',
  },
  {
    id: 'ios-session',
    title: 'Sessão expirada no campo',
    symptom: 'A operação pede login ou recusa persistência.',
    likelyCause: 'Token expirado ou internet indisponível.',
    safeAction:
      'Preservar o lote, reconectar a internet e entrar novamente antes de repetir a ação.',
    escalateWhen: 'O login funciona no Web e falha apenas no app.',
  },
]

export const TRAINING_TRACKS: Record<TrainingTrackId, TrainingTrack> = {
  web: {
    id: 'web',
    title: 'Gestão no Web',
    eyebrow: 'Escritório',
    purpose: 'Planejar e acompanhar um Evento do início ao retorno.',
    audience: 'Marcelo e quem organiza estoque e Eventos.',
    durationLabel: '13 capítulos · alvo de 10 a 15 min',
    dependencyLabel: 'Evento de treino e usuário autenticado',
    chapters: webChapters,
    troubleshooting: webTroubleshooting,
  },
  ios: {
    id: 'ios',
    title: 'Operação no iPhone',
    eyebrow: 'Campo',
    purpose: 'Conferir, sair e retornar equipamentos com RFD40 e QR.',
    audience: 'Marcelo e operador no galpão ou Evento.',
    durationLabel: '9 capítulos · alvo de 12 a 18 min',
    dependencyLabel: 'iPhone físico, Zebra RFD40 e tags reais',
    chapters: iosChapters,
    troubleshooting: iosTroubleshooting,
  },
}

export function isTrainingTrackId(value: string): value is TrainingTrackId {
  return value === 'web' || value === 'ios'
}

export function getTrainingTrack(trackId: TrainingTrackId) {
  return TRAINING_TRACKS[trackId]
}

export function trainingChapterExists(trackId: TrainingTrackId, chapterId: string) {
  return TRAINING_TRACKS[trackId].chapters.some((chapter) => chapter.id === chapterId)
}
