import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case japanese = "ja"
    case korean = "ko"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portuguese: return "Português"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chineseSimplified: return "简体中文"
        }
    }
}

struct Loc {
    let lang: AppLanguage

    var usage: String {
        switch lang {
        case .english: return "Usage"
        case .spanish: return "Uso"
        case .french: return "Utilisation"
        case .german: return "Nutzung"
        case .portuguese: return "Utilização"
        case .japanese: return "使用量"
        case .korean: return "사용량"
        case .chineseSimplified: return "用量"
        }
    }

    var settings: String {
        switch lang {
        case .english: return "Settings"
        case .spanish: return "Ajustes"
        case .french: return "Réglages"
        case .german: return "Einstellungen"
        case .portuguese: return "Definições"
        case .japanese: return "設定"
        case .korean: return "설정"
        case .chineseSimplified: return "设置"
        }
    }

    var colors: String {
        switch lang {
        case .english: return "Colors"
        case .spanish: return "Colores"
        case .french: return "Couleurs"
        case .german: return "Farben"
        case .portuguese: return "Cores"
        case .japanese: return "カラー"
        case .korean: return "색상"
        case .chineseSimplified: return "颜色"
        }
    }

    var theme: String {
        switch lang {
        case .english: return "Theme"
        case .spanish: return "Tema"
        case .french: return "Thème"
        case .german: return "Thema"
        case .portuguese: return "Tema"
        case .japanese: return "テーマ"
        case .korean: return "테마"
        case .chineseSimplified: return "主题"
        }
    }

    var claudeColor: String {
        switch lang {
        case .english: return "Claude Color"
        case .spanish: return "Color de Claude"
        case .french: return "Couleur de Claude"
        case .german: return "Claude-Farbe"
        case .portuguese: return "Cor do Claude"
        case .japanese: return "Claude の色"
        case .korean: return "Claude 색상"
        case .chineseSimplified: return "Claude 颜色"
        }
    }

    var codexColor: String {
        switch lang {
        case .english: return "Codex Color"
        case .spanish: return "Color de Codex"
        case .french: return "Couleur de Codex"
        case .german: return "Codex-Farbe"
        case .portuguese: return "Cor do Codex"
        case .japanese: return "Codex の色"
        case .korean: return "Codex 색상"
        case .chineseSimplified: return "Codex 颜色"
        }
    }

    var claudeName: String {
        switch lang {
        case .english: return "Claude Name"
        case .spanish: return "Nombre de Claude"
        case .french: return "Nom de Claude"
        case .german: return "Claude-Name"
        case .portuguese: return "Nome do Claude"
        case .japanese: return "Claude の名前"
        case .korean: return "Claude 이름"
        case .chineseSimplified: return "Claude 名称"
        }
    }

    var codexName: String {
        switch lang {
        case .english: return "Codex Name"
        case .spanish: return "Nombre de Codex"
        case .french: return "Nom de Codex"
        case .german: return "Codex-Name"
        case .portuguese: return "Nome do Codex"
        case .japanese: return "Codex の名前"
        case .korean: return "Codex 이름"
        case .chineseSimplified: return "Codex 名称"
        }
    }

    var agentNamesDesc: String {
        switch lang {
        case .english:
            return "Names can be up to 7 characters. Leave blank to use the default name."
        case .spanish:
            return "Los nombres pueden tener hasta 7 caracteres. Déjalo en blanco para usar el nombre predeterminado."
        case .french:
            return "Les noms peuvent contenir jusqu'à 7 caractères. Laissez vide pour utiliser le nom par défaut."
        case .german:
            return "Namen dürfen bis zu 7 Zeichen lang sein. Leer lassen, um den Standardnamen zu verwenden."
        case .portuguese:
            return "Os nomes podem ter até 7 caracteres. Deixa em branco para usar o nome predefinido."
        case .japanese:
            return "名前は最大 7 文字です。空欄にすると既定の名前を使います。"
        case .korean:
            return "이름은 최대 7자까지 가능합니다. 비워 두면 기본 이름을 사용합니다."
        case .chineseSimplified:
            return "名称最多 7 个字符。留空则使用默认名称。"
        }
    }

    var reset: String {
        switch lang {
        case .english: return "Reset"
        case .spanish: return "Restablecer"
        case .french: return "Réinitialiser"
        case .german: return "Zurücksetzen"
        case .portuguese: return "Repor"
        case .japanese: return "リセット"
        case .korean: return "재설정"
        case .chineseSimplified: return "重置"
        }
    }

    var autoRefresh: String {
        switch lang {
        case .english: return "Auto Refresh"
        case .spanish: return "Actualización automática"
        case .french: return "Actualisation auto"
        case .german: return "Automatische Aktualisierung"
        case .portuguese: return "Atualização automática"
        case .japanese: return "自動更新"
        case .korean: return "자동 새로고침"
        case .chineseSimplified: return "自动刷新"
        }
    }

    var launchAtStartup: String {
        switch lang {
        case .english: return "Launch at Startup"
        case .spanish: return "Iniciar al arrancar"
        case .french: return "Lancer au demarrage"
        case .german: return "Beim Start starten"
        case .portuguese: return "Iniciar com o sistema"
        case .japanese: return "起動時に開始"
        case .korean: return "시동 시 실행"
        case .chineseSimplified: return "开机时启动"
        }
    }

    var refreshOnOpen: String {
        switch lang {
        case .english: return "Refresh on Open"
        case .spanish: return "Actualizar al abrir"
        case .french: return "Actualiser à l'ouverture"
        case .german: return "Beim Öffnen aktualisieren"
        case .portuguese: return "Atualizar ao abrir"
        case .japanese: return "開いたときに更新"
        case .korean: return "열 때 새로고침"
        case .chineseSimplified: return "打开时刷新"
        }
    }

    var refreshOnOpenDesc: String {
        switch lang {
        case .english:
            return "When enabled, AIPace fetches the latest usage every time you click the menu bar item."
        case .spanish:
            return "Si está activado, AIPace obtiene el uso más reciente cada vez que tocas el icono de la barra de menús."
        case .french:
            return "Lorsque cette option est activée, AIPace récupère l'utilisation la plus récente chaque fois que vous cliquez sur l'icône de la barre des menus."
        case .german:
            return "Wenn aktiviert, ruft AIPace bei jedem Klick auf das Menüleistensymbol die neueste Nutzung ab."
        case .portuguese:
            return "Quando ativo, o AIPace obtém a utilização mais recente sempre que clicas no ícone da barra de menus."
        case .japanese:
            return "有効にすると、メニューバーのアイコンをクリックするたびに最新の使用量を取得します。"
        case .korean:
            return "활성화하면 메뉴 막대 아이콘을 클릭할 때마다 최신 사용량을 가져옵니다."
        case .chineseSimplified:
            return "启用后，每次点击菜单栏图标时 AIPace 都会获取最新用量。"
        }
    }

    var openSystemSettings: String {
        switch lang {
        case .english: return "Open System Settings"
        case .spanish: return "Abrir Ajustes del sistema"
        case .french: return "Ouvrir les Réglages système"
        case .german: return "Systemeinstellungen öffnen"
        case .portuguese: return "Abrir Definições do sistema"
        case .japanese: return "システム設定を開く"
        case .korean: return "시스템 설정 열기"
        case .chineseSimplified: return "打开系统设置"
        }
    }

    var notifications: String {
        switch lang {
        case .english: return "Notifications"
        case .spanish: return "Notificaciones"
        case .french: return "Notifications"
        case .german: return "Mitteilungen"
        case .portuguese: return "Notificações"
        case .japanese: return "通知"
        case .korean: return "알림"
        case .chineseSimplified: return "通知"
        }
    }

    var notificationSound: String {
        switch lang {
        case .english: return "Notification Sound"
        case .spanish: return "Sonido de notificación"
        case .french: return "Son de notification"
        case .german: return "Benachrichtigungston"
        case .portuguese: return "Som de notificação"
        case .japanese: return "通知音"
        case .korean: return "알림 소리"
        case .chineseSimplified: return "通知声音"
        }
    }

    var menuBarDisplay: String {
        switch lang {
        case .english: return "Menu Bar"
        case .spanish: return "Barra de menús"
        case .french: return "Barre des menus"
        case .german: return "Menüleiste"
        case .portuguese: return "Barra de menus"
        case .japanese: return "メニューバー"
        case .korean: return "메뉴 막대"
        case .chineseSimplified: return "菜单栏"
        }
    }

    var popoverDisplay: String {
        switch lang {
        case .english: return "Popover"
        case .spanish: return "Ventana emergente"
        case .french: return "Fenêtre contextuelle"
        case .german: return "Popover"
        case .portuguese: return "Janela emergente"
        case .japanese: return "ポップオーバー"
        case .korean: return "팝오버"
        case .chineseSimplified: return "弹出窗口"
        }
    }

    var remainingSuffix: String {
        switch lang {
        case .english: return "left"
        case .spanish: return "restante"
        case .french: return "restant"
        case .german: return "übrig"
        case .portuguese: return "restante"
        case .japanese: return "残り"
        case .korean: return "남음"
        case .chineseSimplified: return "剩余"
        }
    }

    var providers: String {
        switch lang {
        case .english: return "Providers"
        case .spanish: return "Proveedores"
        case .french: return "Services"
        case .german: return "Dienste"
        case .portuguese: return "Serviços"
        case .japanese: return "プロバイダ"
        case .korean: return "제공자"
        case .chineseSimplified: return "服务"
        }
    }

    var agents: String {
        switch lang {
        case .english: return "Agents"
        case .spanish: return "Agentes"
        case .french: return "Agents"
        case .german: return "Agenten"
        case .portuguese: return "Agentes"
        case .japanese: return "エージェント"
        case .korean: return "에이전트"
        case .chineseSimplified: return "代理"
        }
    }

    var language: String {
        switch lang {
        case .english: return "Language"
        case .spanish: return "Idioma"
        case .french: return "Langue"
        case .german: return "Sprache"
        case .portuguese: return "Idioma"
        case .japanese: return "言語"
        case .korean: return "언어"
        case .chineseSimplified: return "语言"
        }
    }

    var openSettings: String {
        switch lang {
        case .english: return "Open Settings"
        case .spanish: return "Abrir ajustes"
        case .french: return "Ouvrir les réglages"
        case .german: return "Einstellungen öffnen"
        case .portuguese: return "Abrir definições"
        case .japanese: return "設定を開く"
        case .korean: return "설정 열기"
        case .chineseSimplified: return "打开设置"
        }
    }

    var noAgentsMessage: String {
        switch lang {
        case .english: return "No authenticated agents are available."
        case .spanish: return "No hay agentes autenticados disponibles."
        case .french: return "Aucun agent authentifié n'est disponible."
        case .german: return "Keine authentifizierten Agenten verfügbar."
        case .portuguese: return "Não há agentes autenticados disponíveis."
        case .japanese: return "利用可能な認証済みエージェントがありません。"
        case .korean: return "사용 가능한 인증된 에이전트가 없습니다."
        case .chineseSimplified: return "没有可用的已认证代理。"
        }
    }

    var noAgentsHint: String {
        switch lang {
        case .english: return "Open Settings to see availability and setup instructions."
        case .spanish: return "Abre Ajustes para ver el estado y las instrucciones de configuración."
        case .french: return "Ouvrez les réglages pour voir l'état et les instructions de configuration."
        case .german: return "Öffne die Einstellungen, um Status und Einrichtungshinweise zu sehen."
        case .portuguese: return "Abre as definições para ver o estado e as instruções de configuração."
        case .japanese: return "設定を開くと、状態とセットアップ手順を確認できます。"
        case .korean: return "설정에서 상태와 설정 안내를 확인하세요."
        case .chineseSimplified: return "打开设置可查看状态和配置说明。"
        }
    }

    var autoRefreshDesc: String {
        switch lang {
        case .english:
            return "Default is 5 minutes. Manual disables background refresh and uses the refresh button only."
        case .spanish:
            return "El valor predeterminado es 5 minutos. Manual desactiva la actualización en segundo plano y usa solo el botón de refrescar."
        case .french:
            return "La valeur par défaut est de 5 minutes. Le mode manuel désactive l'actualisation en arrière-plan et utilise seulement le bouton."
        case .german:
            return "Standard sind 5 Minuten. Manuell deaktiviert die Hintergrundaktualisierung und nutzt nur den Aktualisieren-Knopf."
        case .portuguese:
            return "O predefinido são 5 minutos. O modo manual desativa a atualização em segundo plano e usa apenas o botão de atualizar."
        case .japanese:
            return "デフォルトは5分です。手動を選ぶとバックグラウンド更新を止め、更新ボタンのみを使います。"
        case .korean:
            return "기본값은 5분입니다. 수동은 백그라운드 새로고침을 끄고 새로고침 버튼만 사용합니다."
        case .chineseSimplified:
            return "默认值为 5 分钟。手动模式会关闭后台刷新，仅使用刷新按钮。"
        }
    }

    var launchAtStartupDesc: String {
        switch lang {
        case .english:
            return "Start AIPace automatically when you log in to your Mac."
        case .spanish:
            return "Inicia AIPace automaticamente cuando inicias sesion en tu Mac."
        case .french:
            return "Lance AIPace automatiquement lorsque vous ouvrez une session sur votre Mac."
        case .german:
            return "Startet AIPace automatisch, wenn du dich an deinem Mac anmeldest."
        case .portuguese:
            return "Inicia o AIPace automaticamente quando inicias sessão no Mac."
        case .japanese:
            return "Mac にログインしたときに AIPace を自動で起動します。"
        case .korean:
            return "Mac에 로그인할 때 AIPace를 자동으로 실행합니다."
        case .chineseSimplified:
            return "登录 Mac 时自动启动 AIPace。"
        }
    }

    var launchAtStartupApprovalDesc: String {
        switch lang {
        case .english:
            return "AIPace is added to Login Items, but macOS still requires approval in System Settings."
        case .spanish:
            return "AIPace se agrego a los elementos de inicio, pero macOS todavia requiere aprobacion en Ajustes del sistema."
        case .french:
            return "AIPace a ete ajoute aux elements d'ouverture, mais macOS demande encore une approbation dans les reglages systeme."
        case .german:
            return "AIPace wurde zu den Anmeldeobjekten hinzugefugt, aber macOS braucht noch eine Freigabe in den Systemeinstellungen."
        case .portuguese:
            return "O AIPace foi adicionado aos itens de início, mas o macOS ainda requer aprovação nas Definições do sistema."
        case .japanese:
            return "AIPace はログイン項目に追加されましたが、macOS のシステム設定でまだ承認が必要です。"
        case .korean:
            return "AIPace가 로그인 항목에 추가되었지만, macOS 시스템 설정에서 아직 승인이 필요합니다."
        case .chineseSimplified:
            return "AIPace 已添加到登录项，但 macOS 仍需要你在系统设置中批准。"
        }
    }

    var launchAtStartupUnsupportedDesc: String {
        switch lang {
        case .english:
            return "Launch at startup is available only from the packaged app."
        case .spanish:
            return "Esta opcion solo esta disponible desde la app empaquetada."
        case .french:
            return "Cette option est disponible uniquement depuis l'application empaquetee."
        case .german:
            return "Diese Option ist nur in der gebundelten App verfugbar."
        case .portuguese:
            return "Esta opção só está disponível a partir da app empacotada."
        case .japanese:
            return "このオプションはパッケージ化されたアプリでのみ利用できます。"
        case .korean:
            return "이 옵션은 패키징된 앱에서만 사용할 수 있습니다."
        case .chineseSimplified:
            return "此选项仅在打包后的应用中可用。"
        }
    }

    var notificationsDesc: String {
        switch lang {
        case .english:
            return "Tap the bell icon on any row to get notified when that usage window resets."
        case .spanish:
            return "Pulsa la campana de cualquier fila para recibir una notificación cuando se reinicie esa ventana de uso."
        case .french:
            return "Touchez la cloche d'une ligne pour être averti lorsque cette fenêtre d'utilisation se réinitialise."
        case .german:
            return "Tippe auf die Glocke einer Zeile, um benachrichtigt zu werden, wenn sich dieses Nutzungsfenster zurücksetzt."
        case .portuguese:
            return "Toca no ícone da campainha em qualquer linha para seres notificado quando essa janela de uso reiniciar."
        case .japanese:
            return "各行のベルを押すと、その使用量ウィンドウがリセットされたときに通知されます。"
        case .korean:
            return "종 아이콘을 탭하면 사용량 갱신 시 알림을 받을 수 있습니다."
        case .chineseSimplified:
            return "点击任一行的铃铛图标，即可在该用量窗口重置时收到通知。"
        }
    }

    var notificationsDisabledWarning: String {
        switch lang {
        case .english:
            return "Notifications are turned off for AIPace in System Settings. Bell alerts were disabled and will not fire until you re-enable notifications for the app."
        case .spanish:
            return "Las notificaciones están desactivadas para AIPace en Ajustes del sistema. Las alertas de campana se desactivaron y no funcionarán hasta que vuelvas a activar las notificaciones para la app."
        case .french:
            return "Les notifications sont désactivées pour AIPace dans les Réglages système. Les alertes de cloche ont été désactivées et ne fonctionneront pas tant que vous n’aurez pas réactivé les notifications pour l’app."
        case .german:
            return "Benachrichtigungen sind für AIPace in den Systemeinstellungen deaktiviert. Die Glockenalarme wurden ausgeschaltet und funktionieren erst wieder, wenn du Benachrichtigungen für die App erneut aktivierst."
        case .portuguese:
            return "As notificações estão desativadas para o AIPace nas Definições do sistema. Os alertas de campainha foram desativados e não vão disparar até voltares a ativar as notificações para a app."
        case .japanese:
            return "AIPace の通知はシステム設定でオフになっています。ベル通知は自動的に無効化され、アプリの通知を再度有効にするまで動作しません。"
        case .korean:
            return "시스템 설정에서 AIPace 알림이 꺼져 있습니다. 종 알림은 자동으로 비활성화되며, 앱 알림을 다시 켜기 전까지 동작하지 않습니다."
        case .chineseSimplified:
            return "AIPace 的通知已在系统设置中关闭。铃铛提醒已自动关闭，在重新为该应用开启通知前不会生效。"
        }
    }

    var colorsDesc: String {
        switch lang {
        case .english:
            return "Pick a color or enter a hex value like #F26B1D. Reset returns that provider to the current theme color."
        case .spanish:
            return "Elige un color o escribe un valor hex como #F26B1D. Restablecer devuelve ese servicio al color del tema actual."
        case .french:
            return "Choisissez une couleur ou saisissez une valeur hexadécimale comme #F26B1D. Réinitialiser rétablit la couleur du thème actuel pour ce service."
        case .german:
            return "Wähle eine Farbe oder gib einen Hex-Wert wie #F26B1D ein. Zurücksetzen stellt für diesen Dienst die aktuelle Themenfarbe wieder her."
        case .portuguese:
            return "Escolhe uma cor ou introduz um valor hexadecimal como #F26B1D. Repor devolve esse serviço à cor do tema atual."
        case .japanese:
            return "色を選ぶか、#F26B1D のような 16 進数の値を入力してください。リセットすると、そのサービスは現在のテーマ色に戻ります。"
        case .korean:
            return "색을 고르거나 #F26B1D 같은 헥스 값을 입력하세요. 재설정을 누르면 해당 서비스는 현재 테마 색상으로 돌아갑니다."
        case .chineseSimplified:
            return "选择颜色，或输入类似 #F26B1D 的十六进制值。重置会让该服务恢复为当前主题颜色。"
        }
    }

    var providersDesc: String {
        switch lang {
        case .english:
            return "Codex uses codex app-server. Claude reads credentials from file, Keychain, then CLAUDE_CODE_OAUTH_TOKEN."
        case .spanish:
            return "Codex usa codex app-server. Claude lee credenciales desde archivo, Llavero y luego CLAUDE_CODE_OAUTH_TOKEN."
        case .french:
            return "Codex utilise codex app-server. Claude lit les identifiants depuis le fichier, le Trousseau, puis CLAUDE_CODE_OAUTH_TOKEN."
        case .german:
            return "Codex verwendet codex app-server. Claude liest Anmeldedaten aus Datei, Schlüsselbund und danach CLAUDE_CODE_OAUTH_TOKEN."
        case .portuguese:
            return "O Codex usa o codex app-server. O Claude lê credenciais do ficheiro, do Porta-chaves e depois de CLAUDE_CODE_OAUTH_TOKEN."
        case .japanese:
            return "Codex は codex app-server を使います。Claude はファイル、キーチェーン、CLAUDE_CODE_OAUTH_TOKEN の順で認証情報を読み込みます。"
        case .korean:
            return "Codex는 codex app-server를 사용합니다. Claude는 파일, 키체인, CLAUDE_CODE_OAUTH_TOKEN 순으로 자격 증명을 읽습니다."
        case .chineseSimplified:
            return "Codex 使用 codex app-server。Claude 会依次从文件、钥匙串和 CLAUDE_CODE_OAUTH_TOKEN 读取凭证。"
        }
    }

    func windowLabel(_ kind: UsageWindowKind) -> String {
        switch kind {
        case .fiveHour:
            switch lang {
            case .english, .spanish, .french, .german, .portuguese, .japanese, .chineseSimplified:
                return "5h"
            case .korean:
                return "5시간"
            }
        case .weekly:
            switch lang {
            case .english: return "Week"
            case .spanish: return "Semana"
            case .french: return "Semaine"
            case .german: return "Woche"
            case .portuguese: return "Semana"
            case .japanese: return "週"
            case .korean: return "주간"
            case .chineseSimplified: return "周"
            }
        }
    }

    func refreshLabel(_ interval: AutoRefreshInterval) -> String {
        switch lang {
        case .english:
            return interval.label
        case .spanish:
            switch interval {
            case .manual: return "Manual"
            case .oneMinute: return "1 minuto"
            case .twoMinutes: return "2 minutos"
            case .fiveMinutes: return "5 minutos"
            case .tenMinutes: return "10 minutos"
            case .fifteenMinutes: return "15 minutos"
            case .thirtyMinutes: return "30 minutos"
            }
        case .french:
            switch interval {
            case .manual: return "Manuel"
            case .oneMinute: return "1 minute"
            case .twoMinutes: return "2 minutes"
            case .fiveMinutes: return "5 minutes"
            case .tenMinutes: return "10 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .thirtyMinutes: return "30 minutes"
            }
        case .german:
            switch interval {
            case .manual: return "Manuell"
            case .oneMinute: return "1 Minute"
            case .twoMinutes: return "2 Minuten"
            case .fiveMinutes: return "5 Minuten"
            case .tenMinutes: return "10 Minuten"
            case .fifteenMinutes: return "15 Minuten"
            case .thirtyMinutes: return "30 Minuten"
            }
        case .portuguese:
            switch interval {
            case .manual: return "Manual"
            case .oneMinute: return "1 minuto"
            case .twoMinutes: return "2 minutos"
            case .fiveMinutes: return "5 minutos"
            case .tenMinutes: return "10 minutos"
            case .fifteenMinutes: return "15 minutos"
            case .thirtyMinutes: return "30 minutos"
            }
        case .japanese:
            switch interval {
            case .manual: return "手動"
            case .oneMinute: return "1分"
            case .twoMinutes: return "2分"
            case .fiveMinutes: return "5分"
            case .tenMinutes: return "10分"
            case .fifteenMinutes: return "15分"
            case .thirtyMinutes: return "30分"
            }
        case .korean:
            switch interval {
            case .manual: return "수동"
            case .oneMinute: return "1분"
            case .twoMinutes: return "2분"
            case .fiveMinutes: return "5분"
            case .tenMinutes: return "10분"
            case .fifteenMinutes: return "15분"
            case .thirtyMinutes: return "30분"
            }
        case .chineseSimplified:
            switch interval {
            case .manual: return "手动"
            case .oneMinute: return "1 分钟"
            case .twoMinutes: return "2 分钟"
            case .fiveMinutes: return "5 分钟"
            case .tenMinutes: return "10 分钟"
            case .fifteenMinutes: return "15 分钟"
            case .thirtyMinutes: return "30 分钟"
            }
        }
    }

    func notificationSoundLabel(_ option: NotificationSoundOption) -> String {
        switch option {
        case .systemDefault:
            switch lang {
            case .english: return "System Default"
            case .spanish: return "Predeterminado"
            case .french: return "Par défaut"
            case .german: return "Standard"
            case .portuguese: return "Predefinição"
            case .japanese: return "システム標準"
            case .korean: return "시스템 기본값"
            case .chineseSimplified: return "系统默认"
            }
        case .glass:
            return "Glass"
        case .hero:
            return "Hero"
        case .purr:
            return "Purr"
        case .frog:
            return "Frog"
        case .bottle:
            return "Bottle"
        case .submarine:
            return "Submarine"
        case .silent:
            switch lang {
            case .english: return "Silent"
            case .spanish: return "Silencio"
            case .french: return "Silencieux"
            case .german: return "Lautlos"
            case .portuguese: return "Silêncio"
            case .japanese: return "無音"
            case .korean: return "무음"
            case .chineseSimplified: return "静音"
            }
        }
    }

    func displayMessage(_ message: String?) -> String {
        guard let message else { return "—" }
        switch (lang, message) {
        case (.spanish, "Loading…"): return "Cargando…"
        case (.french, "Loading…"): return "Chargement…"
        case (.german, "Loading…"): return "Lädt…"
        case (.portuguese, "Loading…"): return "A carregar…"
        case (.japanese, "Loading…"): return "読み込み中…"
        case (.korean, "Loading…"): return "로딩 중…"
        case (.chineseSimplified, "Loading…"): return "加载中…"
        default: break
        }
        return message
    }

    func insightMessage(delta: Double) -> String {
        let pct = Int(abs(delta).rounded())
        switch delta {
        case ..<(-5):
            switch lang {
            case .english: return "\(pct)% over pace"
            case .spanish: return "\(pct)% por encima del ritmo"
            case .french: return "\(pct)% au-dessus du rythme"
            case .german: return "\(pct)% über dem Soll"
            case .portuguese: return "\(pct)% acima do ritmo"
            case .japanese: return "\(pct)% ペース超過"
            case .korean: return "\(pct)% 초과 사용 중"
            case .chineseSimplified: return "\(pct)% 超出节奏"
            }
        case -5...5:
            switch lang {
            case .english: return "On pace"
            case .spanish: return "En ritmo"
            case .french: return "Dans le rythme"
            case .german: return "Im Soll"
            case .portuguese: return "No ritmo"
            case .japanese: return "順調"
            case .korean: return "적정 사용 중"
            case .chineseSimplified: return "节奏正常"
            }
        default:
            switch lang {
            case .english: return "\(pct)% to spare"
            case .spanish: return "\(pct)% de margen"
            case .french: return "\(pct)% de marge"
            case .german: return "\(pct)% Reserve"
            case .portuguese: return "\(pct)% de margem"
            case .japanese: return "\(pct)% 余裕あり"
            case .korean: return "\(pct)% 여유"
            case .chineseSimplified: return "还有 \(pct)% 余量"
            }
        }
    }

    func menuBarDisplayLabel(_ mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .usage:
            switch lang {
            case .english: return "Usage %"
            case .spanish: return "Uso %"
            case .french: return "Utilisation %"
            case .german: return "Nutzung %"
            case .portuguese: return "Utilização %"
            case .japanese: return "使用率 %"
            case .korean: return "사용률 %"
            case .chineseSimplified: return "用量 %"
            }
        case .remaining:
            switch lang {
            case .english: return "Remaining %"
            case .spanish: return "Restante %"
            case .french: return "Restant %"
            case .german: return "Verbleibend %"
            case .portuguese: return "Restante %"
            case .japanese: return "残り %"
            case .korean: return "남은 %"
            case .chineseSimplified: return "剩余 %"
            }
        case .insight:
            switch lang {
            case .english: return "Insight +/-%"
            case .spanish: return "Ritmo +/-%"
            case .french: return "Tendance +/-%"
            case .german: return "Tendenz +/-%"
            case .portuguese: return "Tendência +/-%"
            case .japanese: return "インサイト +/-%"
            case .korean: return "인사이트 +/-%"
            case .chineseSimplified: return "洞察 +/-%"
            }
        case .usageAndInsight:
            switch lang {
            case .english: return "Usage % + Insight"
            case .spanish: return "Uso % + ritmo"
            case .french: return "Utilisation % + tendance"
            case .german: return "Nutzung % + Tendenz"
            case .portuguese: return "Utilização % + tendência"
            case .japanese: return "使用率 % + インサイト"
            case .korean: return "사용률 % + 인사이트"
            case .chineseSimplified: return "用量 % + 洞察"
            }
        case .remainingAndInsight:
            switch lang {
            case .english: return "Remaining % + Insight"
            case .spanish: return "Restante % + ritmo"
            case .french: return "Restant % + tendance"
            case .german: return "Verbleibend % + Tendenz"
            case .portuguese: return "Restante % + tendência"
            case .japanese: return "残り % + インサイト"
            case .korean: return "남은 % + 인사이트"
            case .chineseSimplified: return "剩余 % + 洞察"
            }
        }
    }

    func popoverDisplayLabel(_ mode: PopoverDisplayMode) -> String {
        switch mode {
        case .usage:
            switch lang {
            case .english: return "Usage %"
            case .spanish: return "Uso %"
            case .french: return "Utilisation %"
            case .german: return "Nutzung %"
            case .portuguese: return "Utilização %"
            case .japanese: return "使用率 %"
            case .korean: return "사용률 %"
            case .chineseSimplified: return "用量 %"
            }
        case .remaining:
            switch lang {
            case .english: return "Remaining %"
            case .spanish: return "Restante %"
            case .french: return "Restant %"
            case .german: return "Verbleibend %"
            case .portuguese: return "Restante %"
            case .japanese: return "残り %"
            case .korean: return "남은 %"
            case .chineseSimplified: return "剩余 %"
            }
        }
    }

    func statusTitle(_ status: AgentStatus) -> String {
        switch status.availability {
        case .loading:
            switch lang {
            case .english: return "Checking…"
            case .spanish: return "Comprobando…"
            case .french: return "Vérification…"
            case .german: return "Prüfen…"
            case .portuguese: return "A verificar…"
            case .japanese: return "確認中…"
            case .korean: return "확인 중…"
            case .chineseSimplified: return "检查中…"
            }
        case .available:
            switch lang {
            case .english: return "Available"
            case .spanish: return "Disponible"
            case .french: return "Disponible"
            case .german: return "Verfügbar"
            case .portuguese: return "Disponível"
            case .japanese: return "利用可能"
            case .korean: return "사용 가능"
            case .chineseSimplified: return "可用"
            }
        case .missingAuth:
            switch lang {
            case .english: return "Auth not found"
            case .spanish: return "Sin autenticación"
            case .french: return "Authentification absente"
            case .german: return "Anmeldung fehlt"
            case .portuguese: return "Autenticação em falta"
            case .japanese: return "認証が見つかりません"
            case .korean: return "인증 정보 없음"
            case .chineseSimplified: return "未找到认证"
            }
        case .accessDenied:
            switch lang {
            case .english: return "Access denied"
            case .spanish: return "Acceso denegado"
            case .french: return "Accès refusé"
            case .german: return "Zugriff verweigert"
            case .portuguese: return "Acesso negado"
            case .japanese: return "アクセス拒否"
            case .korean: return "접근 거부됨"
            case .chineseSimplified: return "访问被拒绝"
            }
        case .sessionExpired:
            switch lang {
            case .english: return "Session expired"
            case .spanish: return "Sesión expirada"
            case .french: return "Session expirée"
            case .german: return "Sitzung abgelaufen"
            case .portuguese: return "Sessão expirada"
            case .japanese: return "セッション期限切れ"
            case .korean: return "세션 만료"
            case .chineseSimplified: return "会话已过期"
            }
        case .notInstalled:
            switch lang {
            case .english: return "Not installed"
            case .spanish: return "No instalado"
            case .french: return "Non installé"
            case .german: return "Nicht installiert"
            case .portuguese: return "Não instalado"
            case .japanese: return "未インストール"
            case .korean: return "설치되지 않음"
            case .chineseSimplified: return "未安装"
            }
        case .notLoggedIn:
            switch lang {
            case .english: return "Not signed in"
            case .spanish: return "Sin iniciar sesión"
            case .french: return "Non connecté"
            case .german: return "Nicht angemeldet"
            case .portuguese: return "Sem sessão iniciada"
            case .japanese: return "未サインイン"
            case .korean: return "로그인되지 않음"
            case .chineseSimplified: return "未登录"
            }
        case .error:
            switch lang {
            case .english: return "Error"
            case .spanish: return "Error"
            case .french: return "Erreur"
            case .german: return "Fehler"
            case .portuguese: return "Erro"
            case .japanese: return "エラー"
            case .korean: return "오류"
            case .chineseSimplified: return "错误"
            }
        }
    }

    func statusInstruction(_ status: AgentStatus) -> String? {
        switch (status.provider, status.availability) {
        case (_, .available), (_, .loading):
            return nil
        case (.claude, .missingAuth):
            switch lang {
            case .english: return "Run `claude` in Terminal, then run `/login`."
            case .spanish: return "Ejecuta `claude` en Terminal y luego `/login`."
            case .french: return "Lancez `claude` dans le Terminal, puis exécutez `/login`."
            case .german: return "Starte `claude` im Terminal und führe dann `/login` aus."
            case .portuguese: return "Executa `claude` no Terminal e depois executa `/login`."
            case .japanese: return "Terminal で `claude` を実行し、その後 `/login` を実行してください。"
            case .korean: return "터미널에서 `claude`를 실행한 다음 `/login`을 실행하세요."
            case .chineseSimplified: return "在终端运行 `claude`，然后执行 `/login`。"
            }
        case (.claude, .accessDenied):
            switch lang {
            case .english: return "Allow Keychain access for `Claude Code-credentials`, or run `claude` in Terminal and then `/login`."
            case .spanish: return "Permite el acceso al llavero para `Claude Code-credentials`, o ejecuta `claude` en Terminal y luego `/login`."
            case .french: return "Autorisez l'accès au Trousseau pour `Claude Code-credentials`, ou lancez `claude` dans le Terminal puis `/login`."
            case .german: return "Erlaube den Schlüsselbundzugriff für `Claude Code-credentials` oder starte `claude` im Terminal und dann `/login`."
            case .portuguese: return "Permite o acesso ao Porta-chaves para `Claude Code-credentials`, ou executa `claude` no Terminal e depois `/login`."
            case .japanese: return "`Claude Code-credentials` へのキーチェーンアクセスを許可するか、Terminal で `claude` を実行してから `/login` を実行してください。"
            case .korean: return "`Claude Code-credentials`에 대한 키체인 접근을 허용하거나, 터미널에서 `claude`를 실행한 다음 `/login`을 실행하세요."
            case .chineseSimplified: return "允许 `Claude Code-credentials` 的钥匙串访问，或在终端运行 `claude` 后执行 `/login`。"
            }
        case (.claude, .sessionExpired):
            switch lang {
            case .english: return "Run `claude` in Terminal, then run `/login` again."
            case .spanish: return "Ejecuta `claude` en Terminal y luego `/login` de nuevo."
            case .french: return "Lancez `claude` dans le Terminal, puis exécutez `/login` à nouveau."
            case .german: return "Starte `claude` im Terminal und führe dann erneut `/login` aus."
            case .portuguese: return "Executa `claude` no Terminal e depois executa `/login` novamente."
            case .japanese: return "Terminal で `claude` を実行し、その後もう一度 `/login` を実行してください。"
            case .korean: return "터미널에서 `claude`를 실행한 다음 `/login`을 다시 실행하세요."
            case .chineseSimplified: return "在终端运行 `claude`，然后再次执行 `/login`。"
            }
        case (.codex, .notInstalled):
            switch lang {
            case .english: return "Install the Codex CLI and make sure `codex` is on PATH."
            case .spanish: return "Instala la CLI de Codex y asegúrate de que `codex` esté en PATH."
            case .french: return "Installez l'interface CLI Codex et assurez-vous que `codex` est dans le PATH."
            case .german: return "Installiere die Codex-CLI und stelle sicher, dass `codex` im PATH liegt."
            case .portuguese: return "Instala o Codex CLI e certifica-te que `codex` está no PATH."
            case .japanese: return "Codex CLI をインストールし、`codex` が PATH にあることを確認してください。"
            case .korean: return "Codex CLI를 설치하고 `codex`가 PATH에 있는지 확인하세요."
            case .chineseSimplified: return "安装 Codex CLI，并确保 `codex` 已加入 PATH。"
            }
        case (.codex, .notLoggedIn):
            switch lang {
            case .english: return "Run `codex` in Terminal, then run `/login`."
            case .spanish: return "Ejecuta `codex` en Terminal y luego `/login`."
            case .french: return "Lancez `codex` dans le Terminal, puis exécutez `/login`."
            case .german: return "Starte `codex` im Terminal und führe dann `/login` aus."
            case .portuguese: return "Executa `codex` no Terminal e depois executa `/login`."
            case .japanese: return "Terminal で `codex` を実行し、その後 `/login` を実行してください。"
            case .korean: return "터미널에서 `codex`를 실행한 다음 `/login`을 실행하세요."
            case .chineseSimplified: return "在终端运行 `codex`，然后执行 `/login`。"
            }
        case (_, .error):
            return nil
        default:
            return nil
        }
    }
}
