# OKX Mini Chart

모니터 한쪽에 띄워 두는 작은 macOS 차트 앱입니다. OKX 공개 시세 API에서 봉과 거래량을 받아 실시간으로 그립니다.

- 봉 간격은 1m·5m·15m·1h·4h·1d 입니다. 버튼을 클릭하면 그 간격을 켜고 끄고, 켜진 것들이 위아래로 쌓입니다. 더블클릭하면 그 간격만 남습니다.
- 일봉은 한국 시간 09시(UTC 0시)에 시작합니다(OKX `1Dutc`). 4시간봉은 01·05·09·13·17·21시에 끊깁니다.
- 봉마다 거래량 막대가 붙고, 마우스를 올리면 시가·고가·저가·종가·거래량이 나옵니다.
- 종목 입력칸에 몇 글자만 치면 현물·무기한 선물 후보가 거래대금 순으로 뜹니다. `sox`를 치면 `SOXL-USDT-SWAP`이 나옵니다.
- 보기 → 항상 위에 표시(⌘T)를 켜면 다른 창 위에 고정됩니다.
- 상승은 빨강, 하락은 파랑이고 시간은 맥 시간대를 따릅니다.

로그인이나 API 키는 쓰지 않습니다. 시세를 읽기만 합니다.

## 빌드와 설치

macOS 13 이상과 Xcode Command Line Tools(`swiftc`)가 있으면 됩니다.

```sh
./build.sh           # build/OKX Mini Chart.app 생성
./build.sh install   # ~/Applications 에 복사
```

## 구성

| 경로 | 내용 |
|---|---|
| `web/index.html` | 차트 화면 전체. [Lightweight Charts](https://github.com/tradingview/lightweight-charts) 4.2.0을 CDN에서 불러옵니다 |
| `app/main.swift` | 창·메뉴·WKWebView를 띄우는 AppKit 코드 |
| `app/make-icon.sh` | `AppIcon.icns`를 다시 만들 때 씁니다 |
| `build.sh` | `.app` 번들을 만들고 ad-hoc 서명합니다 |

화면만 고칠 때는 `web/index.html`을 브라우저로 열어 확인한 뒤 `./build.sh install`로 다시 넣으면 됩니다.

## 쓰는 OKX API

- 과거 봉: `GET /api/v5/market/candles` (봉 간격별 300개)
- 실시간 봉: `wss://ws.okx.com/ws/v5/business` 의 `candle1m`·`5m`·`15m`·`1H`·`4H`·`1Dutc`
- 현재가·24시간 등락률: `GET /api/v5/market/ticker` (10초마다)
- 종목 검색: `GET /api/v5/market/tickers` (현물·무기한, 5분 캐시)
