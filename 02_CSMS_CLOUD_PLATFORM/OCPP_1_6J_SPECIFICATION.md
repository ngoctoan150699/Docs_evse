# Äáº¶C Táº¢ CHI TIáº¾T GIAO THá»¨C TRUYá»€N THÃ”NG OCPP 1.6J
## (OPEN CHARGE POINT PROTOCOL 1.6 JSON SPECIFICATION)
### Há»‡ thá»‘ng: THACO EVSE DC Fast Charger & CSMS Cloud Platform

---

## Má»¤C Lá»¤C
1. [Tá»•ng quan Kiáº¿n trÃºc & Háº¡ táº§ng Máº¡ng OCPP](#1-tá»•ng-quan-kiáº¿n-trÃºc--háº¡-táº§ng-máº¡ng-ocpp)
2. [Cáº¥u trÃºc Khung báº£n tin JSON-RPC 2.0](#2-cáº¥u-trÃºc-khung-báº£n-tin-json-rpc-20)
3. [Danh má»¥c Báº£n tin Chiá»u Tráº¡m sáº¡c gá»­i MÃ¡y chá»§ (Client -> CSMS)](#3-danh-má»¥c-báº£n-tin-chiá»u-tráº¡m-sáº¡c-gá»­i-mÃ¡y-chá»§-client---csms)
   - 3.1. BootNotification
   - 3.2. Heartbeat
   - 3.3. StatusNotification
   - 3.4. Authorize
   - 3.5. StartTransaction
   - 3.6. MeterValues
   - 3.7. StopTransaction
   - 3.8. DataTransfer (Vehicle Identity)
   - 3.9. DiagnosticsStatusNotification
   - 3.10. FirmwareStatusNotification
4. [Danh má»¥c Báº£n tin Chiá»u MÃ¡y chá»§ gá»­i Tráº¡m sáº¡c (CSMS -> Client)](#4-danh-má»¥c-báº£n-tin-chiá»u-mÃ¡y-chá»§-gá»­i-tráº¡m-sáº¡c-csms---client)
   - 4.1. RemoteStartTransaction
   - 4.2. RemoteStopTransaction
   - 4.3. Reset
   - 4.4. UnlockConnector
   - 4.5. ChangeAvailability
   - 4.6. ChangeConfiguration
   - 4.7. GetConfiguration
   - 4.8. TriggerMessage
   - 4.9. ClearCache
   - 4.10. ReserveNow & CancelReservation
   - 4.11. SetChargingProfile, ClearChargingProfile & GetCompositeSchedule
   - 4.12. SendLocalList & GetLocalListVersion
   - 4.13. GetDiagnostics & UpdateFirmware
5. [Báº£ng Ma tráº­n Tham sá»‘ Cáº¥u hÃ¬nh (Configuration Keys)](#5-báº£ng-ma-tráº­n-tham-sá»‘-cáº¥u-hÃ¬nh-configuration-keys)
6. [PhÃ¢n tÃ­ch Khoáº£ng trá»‘ng (Gap Analysis) - Dá»± Ã¡n CÃ²n Thiáº¿u Nhá»¯ng GÃ¬?](#6-phÃ¢n-tÃ­ch-khoáº£ng-trá»‘ng-gap-analysis---dá»±-Ã¡n-cÃ²n-thiáº¿u-nhá»¯ng-gÃ¬)
   - 6.1. Khoáº£ng trá»‘ng so vá»›i chuáº©n OCA OCPP 1.6J Edition 2 Ä‘áº§y Ä‘á»§
   - 6.2. So sÃ¡nh vÃ  Lá»™ trÃ¬nh NÃ¢ng cáº¥p lÃªn OCPP 2.0.1
7. [Ká»‹ch báº£n & HÆ°á»›ng dáº«n Kiá»ƒm thá»­ GÃ³i tin Thá»±c táº¿](#7-ká»‹ch-báº£n--hÆ°á»›ng-dáº«n-kiá»ƒm-thá»­-gÃ³i-tin-thá»±c-táº¿)

---

## 1. Tá»”NG QUAN KIáº¾N TRÃšC & Háº  Táº¦NG Máº NG OCPP

Há»‡ sinh thÃ¡i tráº¡m sáº¡c xe Ä‘iá»‡n THACO EVSE triá»ƒn khai giao thá»©c chuáº©n cÃ´ng nghiá»‡p **OCPP 1.6 JSON (OCPP 1.6J)** theo kiáº¿n trÃºc PhÃ¢n tÃ¡n pháº§n cá»©ng vÃ  HÆ°á»›ng sá»± kiá»‡n (Event-Driven Cloud Architecture).

### 1.1. Luá»“ng dá»¯ liá»‡u 3 táº§ng (End-to-End Data Path)

`mermaid
flowchart LR
    subgraph CP ["TRáº M Sáº C HIá»†N TRÆ¯á»œNG"]
        subgraph F4 ["STM32F429 (OCPP Master)"]
            MINI["MiniOCPP Engine\n(Pure C / Static Memory)"]
            CONF["ConfigStore & LocalAuth"]
        end
        subgraph ESP ["ESP32-C6 (Gateway Bridge)"]
            TUNNEL["SPI DMA Tunnel\n(10 MHz / CRC-8)"]
            WSS["WSS Client\n(mbedTLS WebSocket)"]
        end
    end

    subgraph CLOUD ["Há»† THá»NG MÃY CHá»¦ CSMS (GO BACKEND)"]
        GW["ocpp-gateway\n(Port WSS 9000)"]
        VAL["Validation Engine\n(RFC3339 & OCA Schema)"]
        STREAM["Redis Streams\nocpp.inbound"]
        WORKER["Worker Service\n(Billing, State, DB)"]
        PG[("PostgreSQL\nTimescaleDB")]
    end

    MINI <-->|"SPI DMA Frame"| TUNNEL
    TUNNEL <--> WSS
    WSS <-->|"WSS Internet / 4G (Port 9000)"| GW
    GW --> VAL
    VAL --> STREAM
    STREAM --> WORKER
    WORKER --> PG
`

- **Táº§ng Firmware (STM32F429ZIT6)**: Cháº¡y thÆ° viá»‡n MiniOCPP thuáº§n C khÃ´ng cáº¥p phÃ¡t Ä‘á»™ng (malloc), quáº£n lÃ½ phiÃªn sáº¡c, Ä‘á»“ng há»“ nÄƒng lÆ°á»£ng Wh, mÃ£ tháº» RFID, Ä‘Ã³ng cáº¯t relay cÃ´ng suáº¥t thÃ´ng qua giao tiáº¿p ná»™i bá»™ vá»›i chip an toÃ n STM32H743.
- **Táº§ng Gateway (ESP32-C6 / ESP32-WROOM-32E)**: ÄÃ³ng vai trÃ² cáº§u ná»‘i truyá»n dáº«n trong suá»‘t (Transparent Socket Bridge). ÄÃ³ng gÃ³i frame SPI DMA tá»« F429 vÃ  truyá»n lÃªn Cloud qua giao thá»©c an toÃ n WebSocket Secure (WSS).
- **Táº§ng MÃ¡y chá»§ (CSMS Go Backend)**:
  - Microservice cmd/ocpp-gateway láº¯ng nghe táº¡i cá»•ng 9000, tiáº¿p nháº­n hÃ ng chá»¥c nghÃ¬n káº¿t ná»‘i Ä‘á»“ng thá»i nhá» Goroutine Go siÃªu nháº¹.
  - Kiá»ƒm tra tÃ­nh há»£p lá»‡ cá»§a schema qua internal/ocpp/validation.go vÃ  Ä‘áº©y sá»± kiá»‡n vÃ o Redis Streams ocpp.inbound.
  - Microservice worker tiÃªu thá»¥ message, cáº­p nháº­t tráº¡ng thÃ¡i sÃºng sáº¡c, tÃ­nh cÆ°á»›c theo block thá»i gian vÃ  trá»« tiá»n vÃ­ SePay.

### 1.2. CÆ¡ cháº¿ Báº£o máº­t Káº¿t ná»‘i (Security Profiles)
Theo tÃ i liá»‡u *OCPP 1.6 Security Whitepaper (Edition 3)*:
- **Security Profile 1 (Unsecured)**: ws:// khÃ´ng mÃ£ hÃ³a (chá»‰ dÃ¹ng trong máº¡ng ná»™i bá»™ test phÃ²ng LAB).
- **Security Profile 2 (TLS with HTTP Basic Auth - Äang Ã¡p dá»¥ng production)**:
  - ÄÆ°á»ng truyá»n mÃ£ hÃ³a báº±ng TLS 1.2 / TLS 1.3 (cá»•ng 9000).
  - XÃ¡c thá»±c tráº¡m sáº¡c báº±ng HTTP Basic Authentication header:
    `http
    GET /ocpp/1.6J/EVSE_BMT_01 HTTP/1.1
    Host: csms.thaco.com:9000
    Upgrade: websocket
    Connection: Upgrade
    Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
    Sec-WebSocket-Protocol: ocpp1.6
    Authorization: Basic RVZTRV9JTVRfMDE6VEhBQ09AQXV0aEtleTIwMjY=
    `
    *(Username = chargePointId, Password = uth_key Ä‘Æ°á»£c cáº¥u hÃ¬nh trong Flash/NVS cá»§a tráº¡m).*
- **Security Profile 3 (TLS with Client-side Certificates - Mutual TLS)**: XÃ¡c thá»±c 2 chiá»u báº±ng chá»©ng chá»‰ sá»‘ X.509 cÃ i Ä‘áº·t trong pháº§n cá»©ng an toÃ n (Secure Element ATECC608A).

---

## 2. Cáº¤U TRÃšC KHUNG Báº¢N TIN JSON-RPC 2.0

Má»i báº£n tin trao Ä‘á»•i qua WebSocket Ä‘á»u Ä‘Æ°á»£c Ä‘Ã³ng gÃ³i dÆ°á»›i dáº¡ng máº£ng JSON (Array) vá»›i kÃ­ch thÆ°á»›c vÃ  cáº¥u trÃºc quy chuáº©n:

### 2.1. GÃ³i tin YÃªu cáº§u (CALL - Message Type 2)
Gá»­i Ä‘i tá»« má»™t phÃ­a Ä‘á»ƒ yÃªu cáº§u phÃ­a bÃªn kia thá»±c hiá»‡n tÃ¡c vá»¥:
`json
[2, "<UniqueId>", "<Action>", { <Payload> }]
`
- 2 (Number): Äá»‹nh danh kiá»ƒu tin CALL.
- <UniqueId> (String, tá»‘i Ä‘a 36 kÃ½ tá»±): Chuá»—i Ä‘á»‹nh danh duy nháº¥t (UUIDv4 hoáº·c Epoch millisecond) dÃ¹ng Ä‘á»ƒ khá»›p báº£n tin pháº£n há»“i tÆ°Æ¡ng á»©ng.
- <Action> (String): TÃªn tÃ¡c vá»¥ OCPP (vÃ­ dá»¥: BootNotification, StartTransaction, RemoteStopTransaction).
- <Payload> (Object): Dá»¯ liá»‡u chi tiáº¿t cá»§a tÃ¡c vá»¥.

### 2.2. GÃ³i tin Pháº£n há»“i ThÃ nh cÃ´ng (CALLRESULT - Message Type 3)
BÃªn nháº­n gá»­i tráº£ láº¡i cho phÃ­a gá»­i yÃªu cáº§u khi tÃ¡c vá»¥ Ä‘Æ°á»£c cháº¥p thuáº­n hoáº·c hoÃ n thÃ nh:
`json
[3, "<UniqueId>", { <Payload> }]
`
- 3 (Number): Äá»‹nh danh kiá»ƒu tin CALLRESULT.
- <UniqueId>: Khá»›p chÃ­nh xÃ¡c vá»›i <UniqueId> cá»§a gÃ³i CALL trÆ°á»›c Ä‘Ã³.
- <Payload>: Dá»¯ liá»‡u pháº£n há»“i (chá»©a káº¿t quáº£, tráº¡ng thÃ¡i Accepted, Rejected, hoáº·c dá»¯ liá»‡u Ä‘o Ä‘áº¿m).

### 2.3. GÃ³i tin BÃ¡o lá»—i Giao thá»©c (CALLERROR - Message Type 4)
Gá»­i tráº£ láº¡i khi gÃ³i tin CALL gá»­i sai cáº¥u trÃºc, sai kiá»ƒu dá»¯ liá»‡u hoáº·c khÃ´ng Ä‘Æ°á»£c há»— trá»£:
`json
[4, "<UniqueId>", "<ErrorCode>", "<ErrorDescription>", { <ErrorDetails> }]
`
- 4 (Number): Äá»‹nh danh kiá»ƒu tin CALLERROR.
- <ErrorCode>: MÃ£ lá»—i chuáº©n OCPP 1.6 (xem báº£ng bÃªn dÆ°á»›i).
- <ErrorDescription>: MÃ´ táº£ chi tiáº¿t nguyÃªn nhÃ¢n lá»—i (tá»‘i Ä‘a 255 kÃ½ tá»±).
- <ErrorDetails>: JSON Object má»Ÿ rá»™ng (náº¿u cÃ³, thÆ°á»ng Ä‘á»ƒ {}).

#### Báº£ng Danh má»¥c MÃ£ lá»—i Chuáº©n OCPP (ErrorCode):
| MÃ£ Lá»—i (ErrorCode) | Ã NghÄ©a / TÃ¬nh Huá»‘ng KÃ­ch Hoáº¡t |
| :--- | :--- |
| NotImplemented | TÃ¡c vá»¥ khÃ´ng Ä‘Æ°á»£c triá»ƒn khai trÃªn thiáº¿t bá»‹ hoáº·c há»‡ thá»‘ng. |
| NotSupported | TÃ¡c vá»¥ Ä‘Æ°á»£c nháº­n dáº¡ng nhÆ°ng khÃ´ng Ä‘Æ°á»£c thiáº¿t bá»‹ há»— trá»£ á»Ÿ cháº¿ Ä‘á»™ hiá»‡n táº¡i. |
| InternalError | Lá»—i ná»™i bá»™ khÃ´ng xÃ¡c Ä‘á»‹nh (vÃ­ dá»¥: lá»—i Ä‘á»c Flash, lá»—i bá»™ nhá»›). |
| ProtocolError | Lá»—i luá»“ng giao tiáº¿p (vÃ­ dá»¥: gá»­i StopTransaction khi chÆ°a cÃ³ StartTransaction). |
| SecurityError | Lá»—i xÃ¡c thá»±c, sai máº­t kháº©u AuthKey hoáº·c token bá»‹ thu há»“i. |
| FormationViolation | CÃº phÃ¡p JSON bá»‹ há»ng, thiáº¿u ngoáº·c hoáº·c sai Ä‘á»‹nh dáº¡ng máº£ng. |
| PropertyConstraintViolation | Dá»¯ liá»‡u vÆ°á»£t quÃ¡ giá»›i háº¡n Ä‘á»™ dÃ i hoáº·c náº±m ngoÃ i dáº£i giÃ¡ trá»‹ cho phÃ©p. |
| OccurrenceConstraintViolation | Thiáº¿u trÆ°á»ng báº¯t buá»™c hoáº·c xuáº¥t hiá»‡n trÆ°á»ng khÃ´ng mong muá»‘n. |
| TypeConstraintViolation | Sai kiá»ƒu dá»¯ liá»‡u (vÃ­ dá»¥: gá»­i chuá»—i string vÃ o trÆ°á»ng sá»‘ integer). |

---

## 3. DANH Má»¤C Báº¢N TIN CHIá»€U TRáº M Sáº C Gá»¬I MÃY CHá»¦ (CLIENT -> CSMS)

### 3.1. BootNotification
- **Thá»i Ä‘iá»ƒm gá»­i**: Ngay sau khi vi Ä‘iá»u khiá»ƒn F429 khá»Ÿi Ä‘á»™ng thÃ nh cÃ´ng vÃ  ESP32 thiáº¿t láº­p káº¿t ná»‘i WSS tá»›i CSMS.
- **Má»¥c Ä‘Ã­ch**: Khai bÃ¡o danh tÃ­nh tráº¡m, nhÃ  sáº£n xuáº¥t, model pháº§n cá»©ng, sá»‘ serial vÃ  phiÃªn báº£n firmware hiá»‡n hÃ nh.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-boot-001",
  "BootNotification",
  {
    "chargePointVendor": "THACO_EVSE",
    "chargePointModel": "EVSE_H743_DC180",
    "chargePointSerialNumber": "TH-2026-DC180-0089",
    "firmwareVersion": "v1.0.4-prod-20260918"
  }
]
`

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m):**
`json
[
  3,
  "msg-boot-001",
  {
    "status": "Accepted",
    "currentTime": "2026-09-18T12:35:00.120Z",
    "interval": 60
  }
]
`
*(Ghi chÃº: currentTime Ä‘Æ°á»£c tráº¡m dÃ¹ng Ä‘á»ƒ Ä‘á»“ng bá»™ RTC cá»§a STM32; interval = 60 cáº¥u hÃ¬nh chu ká»³ gá»­i Heartbeat Ä‘á»‹nh ká»³ 60 giÃ¢y).*

---

### 3.2. Heartbeat
- **Thá»i Ä‘iá»ƒm gá»­i**: Äá»‹nh ká»³ theo chu ká»³ HeartbeatInterval (máº·c Ä‘á»‹nh 60 giÃ¢y) khi tráº¡m á»Ÿ tráº¡ng thÃ¡i rá»—i hoáº·c khÃ´ng cÃ³ giao dá»‹ch.
- **Má»¥c Ä‘Ã­ch**: Duy trÃ¬ káº¿t ná»‘i TCP/WebSocket (Keep-Alive) vÃ  Ä‘á»“ng bá»™ Ä‘á»“ng há»“ tráº¡m.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-hb-102938",
  "Heartbeat",
  {}
]
`

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m):**
`json
[
  3,
  "msg-hb-102938",
  {
    "currentTime": "2026-09-18T12:36:00.005Z"
  }
]
`

---

### 3.3. StatusNotification
- **Thá»i Ä‘iá»ƒm gá»­i**: Khi cÃ³ báº¥t ká»³ thay Ä‘á»•i nÃ o vá» tráº¡ng thÃ¡i váº­t lÃ½ cá»§a sÃºng sáº¡c (cáº¯m sÃºng, rÃºt sÃºng, báº¯t Ä‘áº§u náº¡p Ä‘iá»‡n, bÃ¡o lá»—i cháº¡m Ä‘áº¥t, ngáº¯t kháº©n cáº¥p E-Stop).
- **ConnectorId**:   (ToÃ n tráº¡m), 1 (SÃºng sáº¡c DC SÃºng 1), 2 (SÃºng sáº¡c DC SÃºng 2).

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-stat-7812",
  "StatusNotification",
  {
    "connectorId": 1,
    "errorCode": "NoError",
    "status": "Preparing",
    "timestamp": "2026-09-18T12:36:15.890Z"
  }
]
`

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m):**
`json
[
  3,
  "msg-stat-7812",
  {}
]
`

#### Ma tráº­n Tráº¡ng thÃ¡i Connector (Status Enum):
- Available: SÃºng sáº¡c ráº£nh, sáºµn sÃ ng Ä‘Ã³n xe.
- Preparing: ÄÃ£ cáº¯m sÃºng vÃ o xe (CP state B/C), Ä‘ang chá» xÃ¡c thá»±c tháº» hoáº·c báº¥m sáº¡c trÃªn App.
- Charging: RÆ¡-le cÃ´ng suáº¥t DC Ä‘Ã£ Ä‘Ã³ng, dÃ²ng sáº¡c Ä‘ang cháº¡y vÃ o xe.
- SuspendedEV: Xe chá»§ Ä‘á»™ng táº¡m ngÆ°ng dÃ²ng sáº¡c (pin Ä‘áº§y hoáº·c BMS cÃ¢n báº±ng cell).
- SuspendedEVSE: Tráº¡m táº¡m ngÆ°ng cáº¥p Ä‘iá»‡n (quáº£n lÃ½ phá»¥ táº£i hoáº·c quÃ¡ nhiá»‡t táº¡m thá»i).
- Finishing: PhiÃªn sáº¡c hoÃ n táº¥t, rÆ¡-le Ä‘Ã£ ngáº¯t, Ä‘ang chá» ngÆ°á»i dÃ¹ng rÃºt sÃºng khá»i xe.
- Reserved: SÃºng Ä‘ang Ä‘Æ°á»£c Ä‘áº·t trÆ°á»›c bá»Ÿi má»™t tÃ i xáº¿ khÃ¡c.
- Unavailable: SÃºng bá»‹ vÃ´ hiá»‡u hÃ³a cá»¥c bá»™ hoáº·c qua lá»‡nh mÃ¡y chá»§.
- Faulted: Tráº¡m gáº·p sá»± cá»‘ pháº§n cá»©ng hoáº·c an toÃ n Ä‘iá»‡n.

---

### 3.4. Authorize
- **Thá»i Ä‘iá»ƒm gá»­i**: Khi ngÆ°á»i dÃ¹ng quáº¹t tháº» RFID (MIFARE 13.56MHz) lÃªn Ä‘áº§u Ä‘á»c tháº» cá»§a tráº¡m.
- **Má»¥c Ä‘Ã­ch**: Há»i CSMS xem mÃ£ tháº» idTag cÃ³ há»£p lá»‡, Ä‘á»§ sá»‘ dÆ° vÃ  Ä‘Æ°á»£c phÃ©p sáº¡c khÃ´ng.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-auth-4412",
  "Authorize",
  {
    "idTag": "RFID-E4F290A1"
  }
]
`

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m - Cháº¥p thuáº­n):**
`json
[
  3,
  "msg-auth-4412",
  {
    "idTagInfo": {
      "status": "Accepted",
      "expiryDate": "2027-12-31T23:59:59Z",
      "parentIdTag": "CORP-THACO-01"
    }
  }
]
`

**TrÆ°á»ng há»£p Tháº» Bá»‹ Tá»« chá»‘i (Bá»‹ khÃ³a hoáº·c Háº¿t háº¡n):**
`json
[
  3,
  "msg-auth-4412",
  {
    "idTagInfo": {
      "status": "Blocked"
    }
  }
]
`

---

### 3.5. StartTransaction
- **Thá»i Ä‘iá»ƒm gá»­i**: Sau khi xÃ¡c thá»±c thÃ nh cÃ´ng, sÃºng Ä‘Ã£ khÃ³a ngÃ m an toÃ n, tráº¡m kiá»ƒm tra cÃ¡ch Ä‘iá»‡n (Insulation Test) thÃ nh cÃ´ng vÃ  sáºµn sÃ ng phÃ¡t dÃ²ng sáº¡c.
- **Má»¥c Ä‘Ã­ch**: Báº¯t Ä‘áº§u tÃ­nh tiá»n cho phiÃªn sáº¡c.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-txstart-9921",
  "StartTransaction",
  {
    "connectorId": 1,
    "idTag": "RFID-E4F290A1",
    "meterStart": 145020,
    "timestamp": "2026-09-18T12:37:00.000Z"
  }
]
`
*(Ghi chÃº: meterStart = 145020 biá»ƒu thá»‹ sá»‘ cÃ´ng tÆ¡ Ä‘iá»‡n ban Ä‘áº§u lÃ  145.020 kWh).*

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m):**
`json
[
  3,
  "msg-txstart-9921",
  {
    "transactionId": 84920,
    "idTagInfo": {
      "status": "Accepted"
    }
  }
]
`
*(Tráº¡m lÆ°u 	ransactionId = 84920 vÃ o bá»™ nhá»› Ä‘á»ƒ gáº¯n vÃ o táº¥t cáº£ cÃ¡c gÃ³i MeterValues vÃ  StopTransaction).*

---

### 3.6. MeterValues
- **Thá»i Ä‘iá»ƒm gá»­i**: Äá»‹nh ká»³ trong suá»‘t quÃ¡ trÃ¬nh sáº¡c (má»—i 10 giÃ¢y theo cáº¥u hÃ¬nh MeterValueSampleInterval).
- **Má»¥c Ä‘Ã­ch**: BÃ¡o cÃ¡o cÃ¡c thÃ´ng sá»‘ Ä‘o Ä‘áº¿m thá»±c táº¿ (SoC %, V, A, kW, kWh) Ä‘á»ƒ hiá»ƒn thá»‹ lÃªn App vÃ  tÃ­nh cÆ°á»›c theo thá»i gian thá»±c.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-meter-5561",
  "MeterValues",
  {
    "connectorId": 1,
    "transactionId": 84920,
    "meterValue": [
      {
        "timestamp": "2026-09-18T12:40:00.000Z",
        "sampledValue": [
          {
            "value": "153400",
            "measurand": "Energy.Active.Import.Register",
            "unit": "Wh"
          },
          {
            "value": "402.50",
            "measurand": "Voltage",
            "unit": "V"
          },
          {
            "value": "148.60",
            "measurand": "Current.Import",
            "unit": "A"
          },
          {
            "value": "59811.50",
            "measurand": "Power.Active.Import",
            "unit": "W"
          },
          {
            "value": "68.5",
            "measurand": "SoC",
            "unit": "Percent"
          }
        ]
      }
    ]
  }
]
`

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m):**
`json
[
  3,
  "msg-meter-5561",
  {}
]
`

---

### 3.7. StopTransaction
- **Thá»i Ä‘iá»ƒm gá»­i**: Khi phiÃªn sáº¡c dá»«ng láº¡i (do ngÆ°á»i dÃ¹ng quáº¹t tháº» dá»«ng, báº¥m nÃºt trÃªn mÃ n hÃ¬nh HMI, báº¥m dá»«ng trÃªn Mobile App, xe bÃ¡o Ä‘áº§y 100% pin, hoáº·c sá»± cá»‘ E-Stop).
- **Má»¥c Ä‘Ã­ch**: Chá»‘t sá»‘ Ä‘iá»‡n tiÃªu thá»¥, thá»i gian sáº¡c Ä‘á»ƒ CSMS thá»±c hiá»‡n quyáº¿t toÃ¡n hÃ³a Ä‘Æ¡n.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-txstop-8831",
  "StopTransaction",
  {
    "transactionId": 84920,
    "meterStop": 182450,
    "timestamp": "2026-09-18T13:15:30.000Z",
    "reason": "Local"
  }
]
`
*(Sá»‘ Ä‘iá»‡n tiÃªu thá»¥ thá»±c táº¿ = 182450 - 145020 = 37430 Wh = 37.43 kWh).*

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m):**
`json
[
  3,
  "msg-txstop-8831",
  {
    "idTagInfo": {
      "status": "Accepted"
    }
  }
]
`

#### CÃ¡c LÃ½ do Dá»«ng sáº¡c (StopReason Enum):
Local (NgÆ°á»i dÃ¹ng báº¥m HMI / quáº¹t tháº»), Remote (CSMS ra lá»‡nh dá»«ng), EVDisconnected (RÃºt sÃºng), EmergencyStop (NÃºt kháº©n cáº¥p), PowerLoss (Máº¥t Ä‘iá»‡n lÆ°á»›i), Reboot (Khá»Ÿi Ä‘á»™ng láº¡i), UnlockCommand (Lá»‡nh má»Ÿ khÃ³a ngÃ m).

---

### 3.8. DataTransfer (Vehicle Identity)
- **Thá»i Ä‘iá»ƒm gá»­i**: Khi chip STM32H743 giao tiáº¿p thÃ nh cÃ´ng vá»›i ECU xe qua CAN bus / SECC vÃ  Ä‘á»c Ä‘Æ°á»£c cÃ¡c Ä‘á»‹nh danh sá»‘ cá»§a xe.
- **Má»¥c Ä‘Ã­ch**: Chuyá»ƒn tiáº¿p Ä‘á»‹nh danh xe (VIN, EVCC-ID, EMAID) lÃªn CSMS phá»¥c vá»¥ quáº£n lÃ½ Ä‘á»™i xe doanh nghiá»‡p hoáº·c nháº­n diá»‡n xe tá»± Ä‘á»™ng.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-dt-1102",
  "DataTransfer",
  {
    "vendorId": "EVSE_H743",
    "messageId": "VehicleIdentity",
    "data": "{\"vin\":\"VF8A1928490128\",\"evccId\":\"02:00:00:FF:FE:12:34:56\",\"emaid\":\"VN-THA-C1234567-8\"}"
  }
]
`

**GÃ³i tin CALLRESULT [3] (CSMS -> Tráº¡m):**
`json
[
  3,
  "msg-dt-1102",
  {
    "status": "Accepted",
    "data": "Vehicle verified"
  }
]
`

---

### 3.9. DiagnosticsStatusNotification
- **Thá»i Ä‘iá»ƒm gá»­i**: Khi tráº¡m Ä‘ang trong quÃ¡ trÃ¬nh trÃ­ch xuáº¥t vÃ  táº£i nháº­t kÃ½ lá»—i há»‡ thá»‘ng (Diagnostics Log) lÃªn mÃ¡y chá»§ qua HTTP/FTP.

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-diag-991",
  "DiagnosticsStatusNotification",
  {
    "status": "Uploading"
  }
]
`
*(Status bao gá»“m: Idle, Uploaded, UploadFailed, Uploading).*

---

### 3.10. FirmwareStatusNotification
- **Thá»i Ä‘iá»ƒm gá»­i**: BÃ¡o cÃ¡o tiáº¿n Ä‘á»™ cá»§a quÃ¡ trÃ¬nh cáº­p nháº­t pháº§n má»m tráº¡m sáº¡c tá»« xa (OTA).

**GÃ³i tin CALL [2] (Tráº¡m -> CSMS):**
`json
[
  2,
  "msg-fw-772",
  "FirmwareStatusNotification",
  {
    "status": "Installing"
  }
]
`
*(Status bao gá»“m: Downloaded, DownloadFailed, Downloading, Idle, InstallationFailed, Installing, Installed).*

---

## 4. DANH Má»¤C Báº¢N TIN CHIá»€U MÃY CHá»¦ Gá»¬I TRáº M Sáº C (CSMS -> CLIENT)

### 4.1. RemoteStartTransaction
- **Thá»i Ä‘iá»ƒm gá»­i**: Khi tÃ i xáº¿ quÃ©t mÃ£ QR trÃªn trá»¥ sáº¡c vÃ  nháº¥n "Báº¯t Ä‘áº§u sáº¡c" trÃªn á»©ng dá»¥ng THACO Charge Mobile App.
- **Má»¥c Ä‘Ã­ch**: Ra lá»‡nh cho tráº¡m sáº¡c kÃ­ch hoáº¡t sÃºng sáº¡c Ä‘Æ°á»£c chá»‰ Ä‘á»‹nh.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-remstart-101",
  "RemoteStartTransaction",
  {
    "connectorId": 1,
    "idTag": "APP-USER-998822",
    "chargingProfile": {
      "chargingProfileId": 1,
      "stackLevel": 1,
      "chargingProfilePurpose": "TxProfile",
      "chargingProfileKind": "Relative",
      "chargingSchedule": {
        "chargingRateUnit": "A",
        "chargingSchedulePeriod": [
          {
            "startPeriod": 0,
            "limit": 150.0
          }
        ]
      }
    }
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-remstart-101",
  {
    "status": "Accepted"
  }
]
`
*(Náº¿u sÃºng Ä‘ang bá»‹ báº­n hoáº·c chÆ°a cáº¯m vÃ o xe, tráº¡m sáº½ pháº£n há»“i status: "Rejected").*

---

### 4.2. RemoteStopTransaction
- **Thá»i Ä‘iá»ƒm gá»­i**: Khi tÃ i xáº¿ báº¥m nÃºt "Dá»«ng sáº¡c" trÃªn Mobile App hoáº·c Quáº£n trá»‹ viÃªn CSMS ngáº¯t sáº¡c kháº©n cáº¥p tá»« trang Web Admin.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-remstop-102",
  "RemoteStopTransaction",
  {
    "transactionId": 84920
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-remstop-102",
  {
    "status": "Accepted"
  }
]
`

---

### 4.3. Reset
- **Thá»i Ä‘iá»ƒm gá»­i**: Quáº£n trá»‹ viÃªn muá»‘n khá»Ÿi Ä‘á»™ng láº¡i tráº¡m sáº¡c tá»« xa.
- **PhÃ¢n loáº¡i**:
  - Soft: Khá»Ÿi Ä‘á»™ng láº¡i pháº§n má»m MiniOCPP vÃ  cÃ¡c FreeRTOS Task mÃ  khÃ´ng ngáº¯t relay cÃ´ng suáº¥t náº¿u xe Ä‘ang sáº¡c.
  - Hard: KÃ­ch hoáº¡t Watchdog Timer / ngáº¯t nguá»“n tráº¡m Ä‘á»ƒ Reset toÃ n bá»™ vi Ä‘iá»u khiá»ƒn (STM32F4, STM32H7, ESP32).

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-reset-103",
  "Reset",
  {
    "type": "Soft"
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-reset-103",
  {
    "status": "Accepted"
  }
]
`

---

### 4.4. UnlockConnector
- **Thá»i Ä‘iá»ƒm gá»­i**: Kháº¯c phá»¥c sá»± cá»‘ sÃºng sáº¡c bá»‹ káº¹t chá»‘t cÆ¡ khÃ­ trÃªn cá»•ng sáº¡c cá»§a xe sau khi phiÃªn sáº¡c Ä‘Ã£ káº¿t thÃºc.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-unlock-104",
  "UnlockConnector",
  {
    "connectorId": 1
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-unlock-104",
  {
    "status": "Unlocked"
  }
]
`
*(Náº¿u cÆ¡ cáº¥u mÃ´ tÆ¡ chá»‘t sÃºng bá»‹ káº¹t cÆ¡ há»c, tráº¡m sáº½ pháº£n há»“i status: "UnlockFailed").*

---

### 4.5. ChangeAvailability
- **Thá»i Ä‘iá»ƒm gá»­i**: KhÃ³a hoáº·c má»Ÿ sÃºng sáº¡c phá»¥c vá»¥ cÃ´ng tÃ¡c báº£o trÃ¬ ká»¹ thuáº­t.
- **Type**: Inoperative (Ngá»«ng phá»¥c vá»¥), Operative (Má»Ÿ láº¡i bÃ¬nh thÆ°á»ng).

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-avail-105",
  "ChangeAvailability",
  {
    "connectorId": 1,
    "type": "Inoperative"
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-avail-105",
  {
    "status": "Accepted"
  }
]
`
*(Náº¿u xe Ä‘ang sáº¡c dá»Ÿ, tráº¡m pháº£n há»“i status: "Scheduled" Ä‘á»ƒ chuyá»ƒn sang Inoperative ngay sau khi phiÃªn sáº¡c káº¿t thÃºc).*

---

### 4.6. ChangeConfiguration
- **Thá»i Ä‘iá»ƒm gá»­i**: Cáº¥u hÃ¬nh láº¡i cÃ¡c thÃ´ng sá»‘ hoáº¡t Ä‘á»™ng cá»§a tráº¡m tá»« Cloud (chu ká»³ Ä‘o, thá»i gian timeout, v.v.).

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-cfg-106",
  "ChangeConfiguration",
  {
    "key": "MeterValueSampleInterval",
    "value": "15"
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-cfg-106",
  {
    "status": "Accepted"
  }
]
`
*(CÃ¡c tráº¡ng thÃ¡i pháº£n há»“i khÃ¡c: Rejected náº¿u sai giÃ¡ trá»‹, RebootRequired náº¿u cáº§n khá»Ÿi Ä‘á»™ng láº¡i má»›i cÃ³ tÃ¡c dá»¥ng, NotSupported náº¿u key khÃ´ng tá»“n táº¡i).*

---

### 4.7. GetConfiguration
- **Thá»i Ä‘iá»ƒm gá»­i**: CSMS Ä‘á»c giÃ¡ trá»‹ hiá»‡n hÃ nh cá»§a má»™t hoáº·c toÃ n bá»™ tham sá»‘ tráº¡m sáº¡c.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-getcfg-107",
  "GetConfiguration",
  {
    "key": [
      "HeartbeatInterval",
      "MeterValueSampleInterval",
      "NumberOfConnectors"
    ]
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-getcfg-107",
  {
    "configurationKey": [
      {
        "key": "HeartbeatInterval",
        "readonly": false,
        "value": "60"
      },
      {
        "key": "MeterValueSampleInterval",
        "readonly": false,
        "value": "15"
      },
      {
        "key": "NumberOfConnectors",
        "readonly": true,
        "value": "2"
      }
    ],
    "unknownKey": []
  }
]
`

---

### 4.8. TriggerMessage
- **Thá»i Ä‘iá»ƒm gá»­i**: CSMS muá»‘n tráº¡m sáº¡c gá»­i ngay láº­p tá»©c má»™t báº£n tin mÃ  khÃ´ng cáº§n chá» tá»›i chu ká»³ Ä‘á»‹nh ká»³ (phá»¥c vá»¥ Ä‘á»“ng bá»™ tráº¡ng thÃ¡i khi káº¿t ná»‘i láº¡i).
- **CÃ¡c báº£n tin cÃ³ thá»ƒ kÃ­ch hoáº¡t**: BootNotification, Heartbeat, StatusNotification, MeterValues, DiagnosticsStatusNotification, FirmwareStatusNotification.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-trig-108",
  "TriggerMessage",
  {
    "requestedMessage": "StatusNotification",
    "connectorId": 1
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-trig-108",
  {
    "status": "Accepted"
  }
]
`

---

### 4.9. ClearCache
- **Thá»i Ä‘iá»ƒm gá»­i**: XÃ³a toÃ n bá»™ bá»™ nhá»› Ä‘á»‡m xÃ¡c thá»±c RFID táº¡m thá»i trÃªn tráº¡m sáº¡c.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m):**
`json
[
  2,
  "cmd-cc-109",
  "ClearCache",
  {}
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-cc-109",
  {
    "status": "Accepted"
  }
]
`

---

### 4.10. ReserveNow & CancelReservation
- **Má»¥c Ä‘Ã­ch**: Cho phÃ©p tÃ i xáº¿ giá»¯ chá»— sÃºng sáº¡c trÆ°á»›c qua Mobile App khi Ä‘ang trÃªn Ä‘Æ°á»ng tá»›i tráº¡m sáº¡c.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m - ReserveNow):**
`json
[
  2,
  "cmd-res-110",
  "ReserveNow",
  {
    "connectorId": 1,
    "expiryDate": "2026-09-18T13:30:00Z",
    "idTag": "APP-USER-998822",
    "reservationId": 1042
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-res-110",
  {
    "status": "Accepted"
  }
]
`
*(Náº¿u sÃºng Ä‘Ã£ cÃ³ xe khÃ¡c Ä‘ang cáº¯m, tráº¡m pháº£n há»“i status: "Occupied").*

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m - CancelReservation):**
`json
[
  2,
  "cmd-canres-111",
  "CancelReservation",
  {
    "reservationId": 1042
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-canres-111",
  {
    "status": "Accepted"
  }
]
`

---

### 4.11. SetChargingProfile, ClearChargingProfile & GetCompositeSchedule
- **Má»¥c Ä‘Ã­ch (Smart Charging Profile)**: CSMS giá»›i háº¡n cÃ´ng suáº¥t phÃ¡t cá»§a tráº¡m theo khung giá» cao Ä‘iá»ƒm / tháº¥p Ä‘iá»ƒm hoáº·c Ä‘iá»u phá»‘i cÃ¢n báº±ng táº£i theo lÆ°á»›i Ä‘iá»‡n.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m - SetChargingProfile):**
`json
[
  2,
  "cmd-prof-112",
  "SetChargingProfile",
  {
    "connectorId": 1,
    "csChargingProfiles": {
      "chargingProfileId": 12,
      "stackLevel": 1,
      "chargingProfilePurpose": "TxDefaultProfile",
      "chargingProfileKind": "Absolute",
      "chargingSchedule": {
        "duration": 3600,
        "chargingRateUnit": "A",
        "chargingSchedulePeriod": [
          {
            "startPeriod": 0,
            "limit": 100.0,
            "numberPhases": 3
          },
          {
            "startPeriod": 1800,
            "limit": 60.0,
            "numberPhases": 3
          }
        ]
      }
    }
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-prof-112",
  {
    "status": "Accepted"
  }
]
`

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m - GetCompositeSchedule):**
`json
[
  2,
  "cmd-compsch-113",
  "GetCompositeSchedule",
  {
    "connectorId": 1,
    "duration": 1800,
    "chargingRateUnit": "A"
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-compsch-113",
  {
    "status": "Accepted",
    "connectorId": 1,
    "scheduleStart": "2026-09-18T12:45:00Z",
    "chargingSchedule": {
      "duration": 1800,
      "chargingRateUnit": "A",
      "chargingSchedulePeriod": [
        {
          "startPeriod": 0,
          "limit": 100.0
        }
      ]
    }
  }
]
`

---

### 4.12. SendLocalList & GetLocalListVersion
- **Má»¥c Ä‘Ã­ch**: Äá»“ng bá»™ danh sÃ¡ch tháº» offline (Whitelist) xuá»‘ng bá»™ nhá»› Flash cá»§a tráº¡m sáº¡c, phá»¥c vá»¥ sáº¡c kháº©n cáº¥p khi máº¥t máº¡ng.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m - SendLocalList):**
`json
[
  2,
  "cmd-locallist-114",
  "SendLocalList",
  {
    "listVersion": 2,
    "updateType": "Full",
    "localAuthorizationList": [
      {
        "idTag": "RFID-E4F290A1",
        "idTagInfo": {
          "status": "Accepted"
        }
      },
      {
        "idTag": "RFID-VIP-000001",
        "idTagInfo": {
          "status": "Accepted"
        }
      },
      {
        "idTag": "RFID-BAD-999999",
        "idTagInfo": {
          "status": "Blocked"
        }
      }
    ]
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-locallist-114",
  {
    "status": "Accepted"
  }
]
`

---

### 4.13. GetDiagnostics & UpdateFirmware
- **Má»¥c Ä‘Ã­ch**: CSMS kÃ­ch hoáº¡t quÃ¡ trÃ¬nh thu tháº­p log file hoáº·c cáº­p nháº­t OTA tá»« xa.

**GÃ³i tin CALL [2] (CSMS -> Tráº¡m - UpdateFirmware):**
`json
[
  2,
  "cmd-fw-115",
  "UpdateFirmware",
  {
    "location": "https://ota.thaco.com/firmware/evse_v1.0.5_signed.bin",
    "retrieveDate": "2026-09-18T02:00:00Z",
    "retries": 3,
    "retryInterval": 60
  }
]
`

**GÃ³i tin CALLRESULT [3] (Tráº¡m -> CSMS):**
`json
[
  3,
  "cmd-fw-115",
  {}
]
`

---

## 5. Báº¢NG MA TRáº¬N THAM Sá» Cáº¤U HÃŒNH (CONFIGURATION KEYS)

Báº£ng tá»•ng há»£p cÃ¡c tham sá»‘ Ä‘Æ°á»£c quáº£n lÃ½ trong mÃ´-Ä‘un miniocpp_config_store.c cá»§a tráº¡m sáº¡c:

| TÃªn Tham Sá»‘ (Key) | Kiá»ƒu Dá»¯ Liá»‡u | Máº·c Äá»‹nh | Thuá»™c TÃ­nh | Ã NghÄ©a Ká»¹ Thuáº­t |
| :--- | :---: | :---: | :---: | :--- |
| HeartbeatInterval | Integer | 60 | RW | Chu ká»³ (giÃ¢y) gá»­i báº£n tin nhá»‹p tim sá»‘ng Heartbeat. |
| ConnectionTimeOut | Integer | 30 | RW | Thá»i gian (giÃ¢y) chá» cáº¯m sÃºng vÃ o xe sau khi quáº¹t tháº». |
| MeterValueSampleInterval | Integer | 10 | RW | Chu ká»³ (giÃ¢y) trÃ­ch máº«u Ä‘o Ä‘áº¿m gá»­i MeterValues. |
| ClockAlignedDataInterval | Integer |   | RW | Chu ká»³ cÄƒn chá»‰nh Ä‘á»“ng há»“ nÄƒng lÆ°á»£ng (0 = vÃ´ hiá»‡u hÃ³a). |
| NumberOfConnectors | Integer | 2 | R | Sá»‘ lÆ°á»£ng sÃºng sáº¡c váº­t lÃ½ trang bá»‹ trÃªn trá»¥ sáº¡c. |
| AuthorizeRemoteTxRequests| Boolean | 	rue| RW | Báº¯t buá»™c xÃ¡c thá»±c láº¡i idTag khi nháº­n RemoteStart. |
| LocalPreAuthorize | Boolean | alse| RW | Cho phÃ©p cáº¯m sÃºng vÃ  thá»­ cÃ¡ch Ä‘iá»‡n trÆ°á»›c khi quáº¹t tháº». |
| LocalAuthorizeOffline | Boolean | 	rue | RW | Cho phÃ©p quáº¹t tháº» sáº¡c báº±ng danh báº¡ cá»¥c bá»™ khi máº¥t máº¡ng. |
| MeterValuesSampledData | String | Energy.Active.Import.Register,Voltage,Current.Import,Power.Active.Import,SoC | RW | Danh sÃ¡ch Ä‘áº¡i lÆ°á»£ng Ä‘o Ä‘áº¿m Ä‘Ã³ng gÃ³i vÃ o MeterValues. |
| StopTransactionOnEVSideDisconnect | Boolean | 	rue | RW | Tá»± Ä‘á»™ng káº¿t thÃºc phiÃªn sáº¡c khi phÃ­a xe rÃºt sÃºng. |
| StopTransactionOnInvalidId | Boolean | 	rue | RW | Ngáº¯t sáº¡c ngay náº¿u tháº» RFID bá»‹ bÃ¡o máº¥t/khÃ³a giá»¯a chá»«ng. |
| UnlockConnectorOnEVSideDisconnect | Boolean | 	rue | RW | Tá»± nháº£ chá»‘t ngÃ m sÃºng khi xe ngáº¯t tiáº¿p Ä‘iá»ƒm CP/PP. |
| GetConfigurationMaxKeys| Integer | 32 | R | Sá»‘ lÆ°á»£ng key tá»‘i Ä‘a CSMS cÃ³ thá»ƒ truy váº¥n trong 1 lá»‡nh. |
| ResetRetries | Integer | 3 | RW | Sá»‘ láº§n thá»­ khá»Ÿi Ä‘á»™ng láº¡i náº¿u tráº¡m gáº·p lá»—i nghiÃªm trá»ng. |
| WebSocketPingInterval | Integer | 30 | RW | Chu ká»³ ping má»©c WebSocket frame (giÃ¢y). |
| SupportedFeatureProfiles| String | Core,FirmwareManagement,LocalAuthListManagement,Reservation,SmartCharging,RemoteTrigger | R | Danh má»¥c 6 Feature Profiles OCA mÃ  tráº¡m Ä‘Ã£ há»— trá»£. |
| LocalAuthListEnabled | Boolean | 	rue | RW | Báº­t/táº¯t tÃ­nh nÄƒng xÃ¡c thá»±c danh báº¡ ná»™i bá»™ tráº¡m. |
| LocalAuthListMaxLength| Integer | 20 | R | Sá»‘ lÆ°á»£ng tháº» tá»‘i Ä‘a lÆ°u trá»¯ trong bá»™ nhá»› Flash F429. |
| SendLocalListMaxLength| Integer | 20 | R | Sá»‘ tháº» tá»‘i Ä‘a gá»­i trong 1 gÃ³i tin SendLocalList. |
| ReserveConnectorZeroSupported | Boolean | alse | R | KhÃ´ng cho phÃ©p Ä‘áº·t trÆ°á»›c connector 0 (toÃ n tráº¡m). |
| ChargeProfileMaxStackLevel | Integer | 5 | R | Sá»‘ lá»›p chá»“ng profile cÃ´ng suáº¥t tá»‘i Ä‘a cho Smart Charging. |
| ChargingScheduleAllowedChargingRateUnit | String | Current | R | ÄÆ¡n vá»‹ Ä‘iá»u khiá»ƒn dÃ²ng sáº¡c (Current - Ampe). |
| ChargingScheduleMaxPeriods | Integer | 6 | R | Sá»‘ bÆ°á»›c khoáº£ng thá»i gian tá»‘i Ä‘a trong 1 lá»‹ch biá»ƒu sáº¡c. |
| MaxChargingProfilesInstalled | Integer | 5 | R | Sá»‘ lÆ°á»£ng Charging Profile tá»‘i Ä‘a cÃ³ thá»ƒ náº¡p vÃ o RAM. |

---

## 6. PHÃ‚N TÃCH KHOáº¢NG TRá»NG (GAP ANALYSIS) - Dá»° ÃN CÃ’N THIáº¾U NHá»®NG GÃŒ?

Máº·c dÃ¹ dá»± Ã¡n Ä‘Ã£ há»— trá»£ trá»n váº¹n cáº£ 6 Feature Profiles chuáº©n cá»§a OCPP 1.6J trÃªn cáº£ pháº§n cá»©ng STM32F429 vÃ  mÃ¡y chá»§ CSMS Go Backend, Ä‘á»ƒ Ä‘Æ°a há»‡ thá»‘ng vÃ o váº­n hÃ nh thÆ°Æ¡ng máº¡i quy mÃ´ lá»›n (HÃ ng chá»¥c nghÃ¬n cá»•ng sáº¡c toÃ n quá»‘c), há»‡ thá»‘ng cÃ²n má»™t sá»‘ khoáº£ng trá»‘ng ká»¹ thuáº­t cáº§n tiáº¿p tá»¥c hoÃ n thiá»‡n:

### 6.1. Khoáº£ng trá»‘ng so vá»›i TiÃªu chuáº©n OCA OCPP 1.6J Edition 2 Ä‘áº§y Ä‘á»§

`mermaid
graph TD
    subgraph CURRENT ["HIá»†N TRáº NG ÄÃƒ HOÃ€N THÃ€NH"]
        C1["Core Profile 100%"]
        C2["Remote Trigger 100%"]
        C3["Basic Smart Charging (5 profiles)"]
        C4["Basic Local Auth (20 tháº» Flash)"]
        C5["Security Profile 2 (WSS + Basic Auth)"]
    end

    subgraph GAPS ["KHOáº¢NG TRá»NG Cáº¦N HOÃ€N THIá»†N (GAPS)"]
        G1["External Flash Paging cho Local Auth (HÃ ng ngÃ n tháº»)"]
        G2["Dynamic Load Management (DLM) theo cÃ´ng tÆ¡ tá»•ng"]
        G3["Upload Diagnostics Log qua S3 Multipart Presigned URL"]
        G4["Security Profile 3: mTLS vá»›i Chip ATECC608A / TPM"]
        G5["ClearChargingProfile vá»›i bá»™ lá»c Ä‘a tiÃªu chÃ­ sÃ¢u"]
    end

    CURRENT -.-> GAPS
`

1. **Giá»›i háº¡n Dung lÆ°á»£ng Danh báº¡ Cá»¥c bá»™ (Local Auth List Capacity)**:
   - *Hiá»‡n tráº¡ng*: Danh báº¡ offline hiá»‡n Ä‘ang lÆ°u trong bá»™ nhá»› Flash ná»™i cá»§a STM32F429 vá»›i dung lÆ°á»£ng tá»‘i Ä‘a 20 tháº» (LocalAuthListMaxLength = 20).
   - *CÃ²n thiáº¿u*: Cáº§n nÃ¢ng cáº¥p cÆ¡ cháº¿ lÆ°u trá»¯ phÃ¢n trang (Paging) trÃªn External SPI Flash (W25Q64 - 8MB) hoáº·c tháº» nhá»› MicroSD Ä‘á»ƒ lÆ°u trá»¯ tá»« 5,000 Ä‘áº¿n 10,000 tháº» RFID cá»§a cÃ¡c Ä‘á»™i xe há»£p Ä‘á»“ng (Fleet), cho phÃ©p váº­n hÃ nh offline dÃ i ngÃ y khi Ä‘á»©t cÃ¡p quang.
2. **Quáº£n lÃ½ CÃ¢n báº±ng táº£i Äá»™ng (Dynamic Load Management - DLM)**:
   - *Hiá»‡n tráº¡ng*: Smart Charging Profile má»›i há»— trá»£ Ä‘áº·t dÃ²ng cá»‘ Ä‘á»‹nh theo khung giá» Ä‘á»‹nh sáºµn (TxDefaultProfile / ChargePointMaxProfile).
   - *CÃ²n thiáº¿u*: ChÆ°a tÃ­ch há»£p thuáº­t toÃ¡n Ä‘iá»u tiáº¿t cÃ´ng suáº¥t Ä‘á»™ng thá»i gian thá»±c theo Ä‘á»“ng há»“ Ä‘o tá»•ng cá»§a tráº¡m biáº¿n Ã¡p tráº¡m sáº¡c (thÃ´ng qua Modbus TCP Meter) Ä‘á»ƒ chia táº£i linh hoáº¡t giá»¯a cÃ¡c sÃºng sáº¡c khi Ä‘iá»‡n Ã¡p lÆ°á»›i bá»‹ sá»¥t giáº£m.
3. **CÆ¡ cháº¿ Truyá»n nháº­n File Nháº­t kÃ½ & Firmware (Diagnostics / OTA Artifacts)**:
   - *Hiá»‡n tráº¡ng*: Lá»‡nh GetDiagnostics vÃ  UpdateFirmware trÃªn F429 má»›i xá»­ lÃ½ tráº¡ng thÃ¡i mÃ¡y tráº¡ng thÃ¡i (State Machine mock/trigger sang ESP32).
   - *CÃ²n thiáº¿u*: Module ESP32 cáº§n hoÃ n thiá»‡n tiáº¿n trÃ¬nh client HTTPS Multipart Form-Data táº£i file log nÃ©n 	ar.gz trá»±c tiáº¿p lÃªn S3 Presigned URL, cÃ³ cÆ¡ cháº¿ Resume khi rá»›t máº¡ng vÃ  Ä‘á»‘i soÃ¡t mÃ£ bÄƒm SHA-256 trÆ°á»›c khi giáº£i nÃ©n Flash.
4. **Báº£o máº­t Pháº§n cá»©ng Cáº¥p cao (Security Profile 3 - mTLS)**:
   - *Hiá»‡n tráº¡ng*: Tráº¡m Ä‘ang váº­n hÃ nh á»•n Ä‘á»‹nh trÃªn Security Profile 2 (MÃ£ hÃ³a Ä‘Æ°á»ng truyá»n TLS + HTTP Basic Auth qua Username/Password).
   - *CÃ²n thiáº¿u*: ChÆ°a kÃ­ch hoáº¡t Security Profile 3 (XÃ¡c thá»±c 2 chiá»u mTLS vá»›i Client Certificate). Äá»ƒ Ä‘áº¡t chá»©ng nháº­n OCA Security Level 3, tráº¡m cáº§n tÃ­ch há»£p pháº§n cá»©ng Secure Element (nhÆ° Microchip ATECC608A hoáº·c STM32 TrustZone) Ä‘á»ƒ lÆ°u khÃ³a riÃªng tÆ° (Private Key) chá»‘ng trÃ­ch xuáº¥t váº­t lÃ½.

---

### 6.2. So sÃ¡nh vÃ  Lá»™ trÃ¬nh NÃ¢ng cáº¥p lÃªn OCPP 2.0.1

Äá»ƒ Ä‘Ã³n Ä‘áº§u xu hÆ°á»›ng xe Ä‘iá»‡n tháº¿ há»‡ má»›i (VinFast, Hyundai, Porsche, Mercedes) vá»›i cÃ¡c tiÃªu chuáº©n sáº¡c siÃªu nhanh 800V vÃ  sáº¡c tá»± Ä‘á»™ng thÃ´ng minh, dá»± Ã¡n cáº§n hÆ°á»›ng tá»›i lá»™ trÃ¬nh OCPP 2.0.1:

| TiÃªu ChÃ­ So SÃ¡nh | Dá»± Ãn Hiá»‡n Táº¡i (OCPP 1.6J) | Má»¥c TiÃªu TÆ°Æ¡ng Lai (OCPP 2.0.1) | Ã NghÄ©a Chuyá»ƒn Äá»•i |
| :--- | :--- | :--- | :--- |
| **Nháº­n diá»‡n Tá»± Ä‘á»™ng (Plug & Charge)** | Nháº­n diá»‡n qua DataTransfer (VIN/EVCC) káº¿t há»£p tháº» RFID/App. | TÃ­ch há»£p sÃ¢u chuáº©n **ISO 15118-2 / ISO 15118-20**. Quáº£n lÃ½ PKI X.509 Certificate tá»± Ä‘á»™ng. | Cáº¯m sÃºng lÃ  sáº¡c ngay vÃ  trá»« tiá»n tháº» tÃ­n dá»¥ng tá»± Ä‘á»™ng, khÃ´ng cáº§n quáº¹t tháº» hay má»Ÿ Ä‘iá»‡n thoáº¡i. |
| **MÃ´ hÃ¬nh Dá»¯ liá»‡u Thiáº¿t bá»‹ (Device Model)** | Cáº¥u hÃ¬nh pháº³ng qua cÃ¡c chuá»—i ConfigurationKey. | MÃ´ hÃ¬nh phÃ¢n cáº¥p hÆ°á»›ng Ä‘á»‘i tÆ°á»£ng: Component $\rightarrow$ Variable $\rightarrow$ Attribute. | Quáº£n lÃ½ vÃ  giÃ¡m sÃ¡t chi tiáº¿t tá»›i tá»«ng module nguá»“n AcePower, cáº£m biáº¿n nhiá»‡t Ä‘á»™, contactor. |
| **Báº£n tin Quáº£n lÃ½ Giao dá»‹ch (Transactions)** | 3 báº£n tin riÃªng biá»‡t: StartTransaction, MeterValues, StopTransaction. | Gom thÃ nh 1 báº£n tin duy nháº¥t: **TransactionEvent** vá»›i cÃ¡c trigger Started, Updated, Ended. | Giáº£m thiá»ƒu Ä‘á»™ trá»…, tiáº¿t kiá»‡m bÄƒng thÃ´ng 4G vÃ  Ä‘áº£m báº£o tÃ­nh toÃ n váº¹n dá»¯ liá»‡u káº¿ toÃ¡n. |
| **Cáº¥p Ä‘á»™ Báº£o máº­t (Cybersecurity)** | Bá»• sung qua Whitepaper (Security Profile 1/2/3). | **Báº£o máº­t cá»‘t lÃµi tÃ­ch há»£p sáºµn**: TLS 1.3 báº¯t buá»™c, mÃ£ hÃ³a lÆ°u trá»¯, phÃ¢n quyá»n Role-Based RBAC. | Äáº¡t chuáº©n an ninh máº¡ng thanh toÃ¡n vÃ  báº£o vá»‡ háº¡ táº§ng Ä‘iá»‡n lÆ°á»›i quá»‘c gia. |
| **Äiá»u khiá»ƒn LÆ°á»›i Ä‘iá»‡n 2 chiá»u (V2G - Vehicle to Grid)** | ChÆ°a há»— trá»£. | Há»— trá»£ xáº£ Ä‘iá»‡n tá»« xe ngÆ°á»£c vÃ o lÆ°á»›i Ä‘iá»‡n (Bidirectional Power Transfer). | GiÃºp tráº¡m sáº¡c tham gia thá»‹ trÆ°á»ng dá»‹ch vá»¥ phá»¥ trá»£ Ä‘iá»‡n lÆ°á»›i (Demand Response). |

---

## 7. Ká»ŠCH Báº¢N & HÆ¯á»šNG DáºªN KIá»‚M THá»¬ GÃ“I TIN THá»°C Táº¾

Quáº£n trá»‹ viÃªn vÃ  ká»¹ sÆ° láº­p trÃ¬nh cÃ³ thá»ƒ kiá»ƒm thá»­ toÃ n bá»™ cÃ¡c báº£n tin OCPP 1.6J trá»±c tiáº¿p vá»›i CSMS Gateway báº±ng cÃ´ng cá»¥ dÃ²ng lá»‡nh websocat hoáº·c Postman WebSocket Client.

### 7.1. Káº¿t ná»‘i thá»­ nghiá»‡m qua WebSocat
Má»Ÿ terminal vÃ  gÃµ lá»‡nh káº¿t ná»‘i WebSocket cÃ³ kÃ¨m chá»©ng thá»±c Basic Auth:
`ash
websocat -H="Authorization: Basic RVZTRV9JTVRfMDE6VEhBQ09AQXV0aEtleTIwMjY=" \
         -H="Sec-WebSocket-Protocol: ocpp1.6" \
         wss://csms.thaco.com:9000/ocpp/1.6J/EVSE_TEST_001
`

### 7.2. Ká»‹ch báº£n 1: Khá»Ÿi Ä‘á»™ng Tráº¡m (Boot & Heartbeat Flow)
1. **Tráº¡m gá»­i BootNotification:**
   `json
   [2, "test-001", "BootNotification", {"chargePointVendor":"THACO","chargePointModel":"H743","chargePointSerialNumber":"SN-001","firmwareVersion":"v1.0.4"}]
   `
2. **CSMS pháº£n há»“i Accepted:**
   `json
   [3, "test-001", {"status":"Accepted","currentTime":"2026-09-18T12:50:00.000Z","interval":60}]
   `
3. **Tráº¡m gá»­i bÃ¡o tráº¡ng thÃ¡i sÃºng:**
   `json
   [2, "test-002", "StatusNotification", {"connectorId":1,"errorCode":"NoError","status":"Available","timestamp":"2026-09-18T12:50:01.000Z"}]
   `

### 7.3. Ká»‹ch báº£n 2: PhiÃªn Sáº¡c HoÃ n Chá»‰nh tá»« App (Remote Start -> Charging -> Stop)
1. **CSMS gá»­i lá»‡nh RemoteStartTransaction:**
   `json
   [2, "cmd-991", "RemoteStartTransaction", {"connectorId":1,"idTag":"USER-THACO-888"}]
   `
2. **Tráº¡m pháº£n há»“i cháº¥p nháº­n lá»‡nh:**
   `json
   [3, "cmd-991", {"status":"Accepted"}]
   `
3. **Tráº¡m bÃ¡o sÃºng chuyá»ƒn sang tráº¡ng thÃ¡i Preparing rá»“i báº¯t Ä‘áº§u sáº¡c:**
   `json
   [2, "test-003", "StatusNotification", {"connectorId":1,"errorCode":"NoError","status":"Preparing","timestamp":"2026-09-18T12:50:10.000Z"}]
   [2, "test-004", "StartTransaction", {"connectorId":1,"idTag":"USER-THACO-888","meterStart":1000,"timestamp":"2026-09-18T12:50:15.000Z"}]
   `
4. **CSMS pháº£n há»“i táº¡o Transaction ID:**
   `json
   [3, "test-004", {"transactionId":10092,"idTagInfo":{"status":"Accepted"}}]
   `
5. **Tráº¡m Ä‘á»‹nh ká»³ gá»­i dá»¯ liá»‡u Ä‘o Ä‘áº¿m (MeterValues):**
   `json
   [2, "test-005", "MeterValues", {"connectorId":1,"transactionId":10092,"meterValue":[{"timestamp":"2026-09-18T12:50:30.000Z","sampledValue":[{"value":"1250","measurand":"Energy.Active.Import.Register","unit":"Wh"},{"value":"400.0","measurand":"Voltage","unit":"V"},{"value":"100.0","measurand":"Current.Import","unit":"A"},{"value":"40000.0","measurand":"Power.Active.Import","unit":"W"},{"value":"55.0","measurand":"SoC","unit":"Percent"}]}]}]
   `
6. **CSMS gá»­i lá»‡nh dá»«ng sáº¡c tá»« xa RemoteStopTransaction:**
   `json
   [2, "cmd-992", "RemoteStopTransaction", {"transactionId":10092}]
   `
7. **Tráº¡m pháº£n há»“i cháº¥p nháº­n vÃ  gá»­i StopTransaction chá»‘t chá»‰ sá»‘ Ä‘iá»‡n:**
   `json
   [3, "cmd-992", {"status":"Accepted"}]
   [2, "test-006", "StopTransaction", {"transactionId":10092,"meterStop":15000,"timestamp":"2026-09-18T13:00:00.000Z","reason":"Remote"}]
   [3, "test-006", {"idTagInfo":{"status":"Accepted"}}]
   `
8. **Tráº¡m bÃ¡o sÃºng trá»Ÿ láº¡i tráº¡ng thÃ¡i sáºµn sÃ ng (Available):**
   `json
   [2, "test-007", "StatusNotification", {"connectorId":1,"errorCode":"NoError","status":"Available","timestamp":"2026-09-18T13:00:05.000Z"}]
   `

---
*TÃ i liá»‡u nÃ y Ä‘Æ°á»£c biÃªn soáº¡n Ä‘á»™c quyá»n cho Há»‡ thá»‘ng Quáº£n trá»‹ & Váº­n hÃ nh Tráº¡m Sáº¡c Xe Äiá»‡n THACO EVSE. NghiÃªm cáº¥m sao chÃ©p hoáº·c phÃ¢n phá»‘i khi chÆ°a cÃ³ sá»± cháº¥p thuáº­n cá»§a Ban CÃ´ng nghá»‡ ThÃ´ng tin & Tá»± Ä‘á»™ng hÃ³a THACO.*