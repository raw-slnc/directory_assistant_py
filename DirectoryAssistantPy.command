#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${DA_PORT:-8742}"
HOST="127.0.0.1"
URL="http://localhost:${PORT}"

PID_FILE="$ROOT/.server.pid"
LOG_FILE="$ROOT/.server.log"
export PYTHONDONTWRITEBYTECODE=1
if ! ( : >"$LOG_FILE" ) 2>/dev/null; then
  LOG_FILE="/tmp/DirectoryAssistant-${PORT}-$(id -u).log"
  : >"$LOG_FILE" 2>/dev/null || true
fi
exec >>"$LOG_FILE" 2>&1

step(){ echo "STEP $1 $(date '+%F %T')"; }
open_url(){
  local url="$1"
  open "$url" >/dev/null 2>&1 || {
    echo "open_failed=$url"
    return 0
  }
}

close_launcher_terminal(){
  command -v osascript >/dev/null 2>&1 || return 0
  local tty_path=""
  tty_path="$(tty 2>/dev/null || true)"
  [ -n "$tty_path" ] || return 0
  (
    sleep 0.5
    osascript - "$tty_path" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set target_tty to item 1 of argv
tell application "Terminal"
  if it is running then
    try
      set tab_count to 0
      repeat with w in windows
        set tab_count to tab_count + (count of tabs of w)
      end repeat
      if tab_count is less than or equal to 1 then
        quit
        return
      end if
      repeat with w in windows
        repeat with t in tabs of w
          try
            if tty of t is target_tty then
              close t
              return
            end if
          end try
        end repeat
      end repeat
    end try
  end if
end tell
end run
APPLESCRIPT
  ) &
}

da_py_payload(){
  cat <<'B64'
H4sIAAAAAAACA+19a3McyZHY9/kVzaHE7hZnGgMQAMEZDmiSAEVaXJJBYCVtUIzZ
np4aTC96unu7e/DQcCIWpHy2b6WTQ49dO07y+mSFHj6vz+c76eST4hThn7LQrqRP
up/gzHp0V/VjBuDuWlbEEbvATHVVVlZmVlZmVlb1H37564sXliZxtNR3/SXiH2jh
cTIK/Cu1mjsOgyjR4uO4Bv9bg8BPeoeRm5Be/zghTjAgWlfbjSYkrWpHe6EdxUR8
fyMOfPE5iGtBbEEHbhT4VkySARnaEy8x6o9e27378MHWwwe7X3p8b3f71mu727cf
bm3XG1p9uW6K9qFnJ8MgGqdoTfphFDgkjkVJMoqIPXD9vbTAHaeoHJJ+PwoOYxLV
hlEw1kZJEgIW0QGJNF7l7u7uox1a0tBu2THB74/JmxMSJ3dtf+CJpqGdjDy3L5o9
gq/swSTyoNyiJBBPoYyRpFbb2r5z89X7u71HDx/vAuU2rq6upGW37j3YgrL68spV
qwU/y/Xa1s3eF7cf79x7+AAfrLRW1put1ebyhnWlXpMeQF1rpV6rbX/59v1Xt7ah
aFrT4F/d2trp7SRBROoNXsCGa4XuQBRtuRFxoM7xzTh248T2E6tvJ3OeOsF4DLSY
U2NA4v0kCOfUCI+rHz46tuLR3McLMYA6bAyzlCi9rXuPdzLK9HrhsWM7I9LrCTB9
29mfpEhbAwHVFlAZvEf3tnp37t3ffnDzFaS0QtLa3e2bj3dvbd/c7e3ee2X74au7
vZ3t21DrSqtW8+w46YUgm/D9QeCTGmvYc/04SYtGk2QQHPo9L3D2oTCVZ+s+FBhm
VgEFOyo0i5iskkHPTmHW7u6+ch8xrdevX9h6eHv3tUfbIPtjb7N2Hf9onu3vdetv
2HUsgO42gQLXxySxNWeEcpt066/u3mlu1LMHvj0m3fqBSw5RwuuaA4qB+FDx0B0k
o+6AHLgOadIvDc313cS1vWbs2B7pLlstBihxE49spszTUu5dX2KPsJLn+vtaRLxu
3YU+6lpyHELH7tjeI0uhv1fXgEDDbn0Jn1pYkGtlh6FHmkkwcUZNBqG0QZwcsw41
rR0FQcLFRNOazf5e++JwDX5aHfgWuwPStyNaujK4Yq8QuTQhR0n74mCDbAyudVII
4qntOECj9sWrdn/j6gDbOXY0YB3Qf1jUD6IBiQDIOmkN1jMgDPSKgz9YbzwBLrcv
rvevOut9LBgGHjRsOoEXQPM1e8Nec7LmQxfIEA6GAPja6vAK7Z2WHUJ/ALe/5vQ3
0kJy5BCvfXGZXCVX8kCCZIT4XbXxB1uIYa3C91Vee0Z/f27aD45g+F8FAW6zgcH4
jjpjWCRcv93qhPYAhbvdYvX7weB4OgRRag7tsesdt/W7bmRD1UDbsf1Yb+ivEDc6
DuDDaxPt84CJ6+iNGB41YS65Q4EpgoLJvBcFE3/QPrAjA9lodhht2Hekp9kZuDEs
KsftoUeOOiPi7o2S9nKrdTDqBDA1h15w2B65gwHxGYIXOSunVLLbK+ut8KhT6CqT
EbVLWUpMCVf8pyCCv5pM/7iB3wYYk7HPSuNRBLItCCbwaeK0JdFU0HN5IzzSltfx
1wpiKEifJMG4vQzFceC5Ay3a69vGytpaQ/xvtTbMHGRyTHDRZGwBVhKgD4CkXw8Z
wa62Wh2PJAl0EYe2gwhYy2ScG6H4h6NvJhEwDZfy9iQMSeTAUltKKiZbJpcYMYK1
8IhjCcv/G0ClJuojGcUrgCIoAdIUPLXWOijpzT7o0/02/d20PS83WJsSPM7o2HoJ
Eq7nxGrPDtvrAmOrn/hTLG4vp9J/FaBtpH20fVDaor8IlP8kxuYdaXQr4iufJq4P
U9JNJII7kygGYoaBC3o5Uri1Dtyi5HepcGXSq1nLa3EjQA4mx/SLBFAZke25e34T
rMBx3Eb+QA9vTOLEHR43+UIginHsq/LY2wDI7ntkMOUdta3VDseWW4NSZeTHAQGK
JEba0JxmwkNXFMO6tm5mjZp7oyBOptKsLBXz6pmZB9UeoS7IIzEX/vKqDGUA6ytM
zkKLlVZjnf5nLaf4XBy2NuCn0PqMSGQgr6xkIIc2/BOiTuwI1sLDyA5TMb/2clIe
BlyGYKW1kVFqF7jCTtM6dh9AwZoFmmKYtFcAdgdMxPZa67OdjJ/0E8AirxlNeGKW
qJDcNJCkiAt7kxyA7MV0GikIcaUN6v2znYXSwefiPBIs59ArTllB33U2wTX8u7JR
nMsKmOoVo2zKB5ME9VxxtO02zFeHjKhVMGVA2RiW1xsrV1YaK8tXQUpMtdEwcCbx
lI9kjkIWrRI7ybQlXXRW1eEhn6s6X1UJeA7hE9PrYhIRQnWODUSIhGIVa3fzuG1P
kkDhQ6u0ZbsN6rG/7wLaThR4XrbGp9prcYtmMpqM+ws0w4qZ0+0rqXqkHaBWnU5i
XEuJB0ubxFlWARfjRdoY1e4VSQBX+QqTWxZys0vFCxbZ1FDT1pC1OcG11gqL7Goe
ZBXrYYZVrUFxbrBM8xWouryy0ljeWG0sryBV11Jlx4zvHAyLLSTzgaxkGrO/MWz1
+zKQJNjb84hQIUhbMWj8rJhmnUXcKSq1itUzo/aGrOrW1mTipdoTaLcRF3G2gpD4
0poZBTBpiXGtNSB7Zkl1j9jDdHFuVWtVLq6o5HOGV4mhyip7dp9405xl3aEGYVpI
PM8NwRHsHI6AaNSgRO2G65UMyhm53iCCgRWgZZQZ20dcNDVgbqwRsDKboDAlG0cl
mABqOV4Qg4mSAWi3LrBgDrinKSPyRvgQHEfJCN/Iraq43J3LcCx3AxST6uIYlJFQ
e2doXO7VIBDhQhS8Ge6jmpXGAfev6NOyFTs1pq/g8ocE+fgThIpFs0+SQ0IYSZhR
XOIioa0/cCLUzDk5ldc36k6b58cMu14TPaOQtvFXZwwEZboiNeUcptpzKljGQTg7
RcnvnG3OqF1xxUmrDogTRDaVBOAsiVBtZ7UBJ5D6ZFr0j1XLXPEj1lrS0GISKq2F
NJQxhAcqMI40zRlCJRwpIUYZUC4YTRu4vcgMoN7xSrruKm2rDYH1s9YvmgEqTdRl
9kq6/MdsqnItmbOhFvnbrfUKh7uEpJUeuOplX0sxo3GfvcgdpIYHfungL5CTMYbl
0TJCDRODMxASOzGQ4hgw8howF0CRGsvXwJluLA8js6gkcBZdS+0NgUDGIoYBaqKF
+qlSMalkp0GM2hxNtcBW0mTzRTKXmRNNw14jexAcsu/yGh0XQJ1R6V8tUkPYRkV7
XeiSDBOw4lb4isQWn6to96w0rq4zq7QiWlPqmwGNzQIu3MYqeucbhbp5s2FlPW9K
FlrkIzwrReOzPMRTPrCiqivXbRkCUCkVf9enXfcxSt85Z2SstVoxU4X0rTBPsagn
qicuW6nAYRi2mXJM7EjEUbBNOBhq8sy5OHTIBllX9K2IEJtSu0HgHCntyDpxhhvF
dkh4ueGRF+cbDldJv9iQRpqVLt1IRZUQaKlGB+VQt9x27MaOOswW/hR7pTHs1IcM
7DjJAhVD94gMOkIFoTtLIxYVgYovs0CFJs2ODZCCnGcrocQ3DRRvpaMEYjYKvM+F
DK7kVJcyx9HVW2mJOd5q4I+1sqYiVO4+rKzFmjPpuw4YVl91SWRYV0BFWGugINbh
g5nZzStrqhbL3IWvNl2wL47a165dq7TgGcWteASe7NlI2jJTo3tZXoSR58Sf5Jkn
pimNpGam2MpKLlyP2y6CE3xnpSa7wtJaIvZjioxRqE8Dxlfy5MfwHgcs6LO80mrJ
cYmSUTECibFQXcNl3UmOmDF5ljgA4ihFvhTvpJWLOtcK8kqZENpoHpbEpMvCzHn7
WkSq6Lgojm2cULmhFL18PvFFPTqg5jjem55huTx7gLqgiLNNoM9mfkWVEcWGw0AV
EAXD2N2Tlqy1zJyRKo1W5FVtPdeZHJCOQ3D1Slcg23fHzLjHOtpyrOFDO9Jcf4ib
r5yI/2qfHA8jWEdjjcJKgmJY4Mo6iwvwPkfe/JjJlY3KcNZFsSmNljF4aVNlVuZm
rOvHBJxsZXIug55c7uc0JefXJ8R2ymBU8ZLaulYWZy0fkjpDEafyegVJWK8ikioO
qK8q6oV5ZzaNDq3nY1/7/SYL64pY8YoahFAYum6KkHIzGA6RKc0SKzyDeVbTE3+u
lFieLAB9fYlvwF9fYgkI13ErGP4M3APNHXTrPMTCNutzhTxyUWfb94WnfAOzXpZp
oF0H3ebT6gO7CQoodjFFgCLTrWcBN8WoW2216puAMbSEP9BdrmN5T7K++bv/9v7p
ya9/90+/gt+/+cX7lmWlbbIPeZz5PqQYUn8CxoivOZ4dx916P/G1dHOqTtvh14gM
IxKP6psfvPd32kd/+fcfvfM/ry+xlucBQ45CTK3Z/PDf/OTDv/3u7995+2WAgDh4
dhgTCub37/x7GUbJqLMtKTHilC3SXlJ985/f+843OOFZNdcPJ4lUT+SHoNqsa9IG
SLd++uK7p8//6vT5D09f/PXpi1/Srz+ln986ff6tj374vd/+/Q+AOfUKFHGjYz4z
RVV1m0CWSi5WqZ3fEia9vIx0Kje4OChBHc4B1OSU55ww2unz/336/P3TF//19MXf
MRwZBouljsUvBcY2z5TBLLm4vbS05yajSR9zr5Yi+7AZe76zlOZI9dIkqV54DFwA
Px7Thnp9z/b362KR5QRQTJr5FJi7fbRWcFrzsS621Mi7Pxoz6HMuWUm2gmQiZ459
Jx1K4I+DSUzQaAGWj9zYooOzaN2uXrbjoRcaT5KztYWR6mxy7Y1gnns0kI05TvXN
z7vJ3Un/+pI9d3qyPeRsforVJFV1KslBnr75S+23P3v+m3/8s5KpK/4I+cHwsaqZ
pYByXi1n4dh6qfaUooNShaLQykE4uQ8+8szCAihSOSzEUDBvArGuro9WSmc7FOeR
ypODejcp7irC3LRn1OK8YiqLfamn+HO7mPEMv0XkgNgeKsFvP9dUbfafT1984/TF
r06f/4JOe8D3x7/7q5/89of/mDEvj03OnsjYJ9Ppn9/7+v/KRgtDL1tCQXsySTk9
eff05J/o7/coobBRuHl68u3Tk/9x+vzXpy/eOT35G1gNTk/+4+nJj05Pvnl68l9O
T757evK160thhiJg5IbJZg1mqYbKdMtO7K4/8bwGj1M/CAaEFnRoHczF3Q0eB4dd
nxxqr9ihYbIHLCD1yPaJ19VRFegNarSQwS6AvTc46jaXRcltsGpYCWvr2wd3YYAw
1O6Tp40R+yhXsMPwEU9H7up6Azi0S5WehBxwPMaKbhezCXEobcPsbg5J4owMfQke
LGGhblrJiPhG1N2MLEyXNkwTk1DBeA8KDbCwqgHmlhYaYCE0cGwswofTGa2Mu4Lt
UK2LZXpjCnNvFAza+qOHO7t6g03juD3Vb/MptwsCq7d1TK10HapolxALfdZAq639
r3cePgCNFkHHYHkbU+RPO5yZswq0mWDncWGl/++xEROjQEjxII/SrEDcWacGhvM9
VEAHtkfLAYCFnDDMBniWrZbZyUo6taUlENt9ApIMohprVCQxwwesdG3X7i/RAq1P
RvaBCyuRG2O+Lc4/GD9IeRTE8JRltscWFzuUrNvCCukOAAIonsQCCd32CH68BeJs
6Kq1optCarl6vQnatbqxrIOxqdKnldj9e+hUdVsUqACnlFeCllcpEF9YwrdxA/o+
HTSJoG/g9r7esONj36GUxxkzNC5AT0M3Ghv66fOfoSp88R+oZszpqP90evL2H371
nm6aEUkmkY+r/yG4gOAu9XoDewd6ToA5W9A7ZmFHExobsQ9tl05oS6BmUBOkchQ5
LYvzENUrjgKHhBWCQ6TcDP6v7n9oezGhYnKXTCJo7DptZLCdaLeTyLv8WFvS7qxp
dow5z4E9aKDgHBLNgVUu3nfDVKi1yxrd2m5yKlkI8wFYfW0hP9qr9zgQjS9PSxpg
Cp4FiJgdoV509+gsQ+h6AlKJ9V0Q12NtQBJYHsjAksfymEJjae98IPxpkan75JhN
Mc0gnKdMHOFB1yAW/Hn2TEf9F9wPDkl0GwwhxgJWzY1ZbzujIEqcCabAG9i029WH
a7qpPXumGQDGAaJ9AUERC+0M+Ghqly5pvCadBUyY8vBMrVRc5CEKWQENsOuO0cZj
ikGbSxJt1tCuUL1Qg09Txw6hG9JGYCgaw4lPPUKN5/fvcH4+9G8jOw2TS3+FCMlo
q7VSTCpGVjERkuiYJcgzsoMh34enuPzego/Gk7zSnZlPYVRo6JQpam7GA2ZcuoLI
iok/uEVsgG+KVPyyhwXdTHFJ/YJsTCwlfcY0NTGnM3kUZ1Hz51959OlMb+wTEoJz
cyB4qa4VnRxOM5yPX4JlSYO1Cbyo/hLjBVX5NCelIURA4weX0qlt9KG0SYZgkSQm
ndgHbuz2XQ+8R2eEDgBCcSnqgKrtwYR98HBXQ+tH++Ct72jxoQuIoFQmgWb7dI8E
cdAOg4k3AGq5e3tSh1b1NA7tPTICpxLnMZX9KrEFuWfLH/2uca3U1lAtgpcEGB4i
MdxEjzVASLOFbor5hJyDRJ8AJcjEx/qyQvnEpgmxwohmRW3xU2wmK2U1vmh7Ezwc
p+udmhBE+kWZz+EkHj2wDwwfrEYxiTNjc7PbMjND9En24KnlcHtVNV+xK8lyzT5a
MYgoMVqSJXuZ5a9KdRAZY4qoNDj4dnOZCalkAEsNPOLvJSO0iGfZkPaCWzYeVSqM
5jqMJqPeuceV1Wo2M41PuuWAOihCd6gv+dg+BJ1Ph0UEfDOH8p0gOoQnRhkPSgb8
yYzj8uVPZhwMwr3bDx/sdKd4xkcHH/FregPMEvrx+/Tjkfh85MX045/Tj0fisxMf
iI+A1RvhHn5751d/+MU39cYbIZG/hr78DVS89C0+kJ8dkn4ofQXA43AVC/7iv+uN
cXCQfgyv0I8/gyb2gfj4VZc2fvd7tHFkR9I3z9/Hb995V29MIk98TI4SOoi3AeSA
f5oJmxa8764PSoB9C7u+FYPmTgzdghWfz9CQ83hz+UZohQH4kqqt0YYpnALEqCRC
pKR/AuAN33wKBgolf9qr48VSt6TL6okOCZocwDT9hs536vX2Ex34pTfw95H+1HJ9
x5sMSAwqjFWi5VAL2Ae1kIlltWh5Wxcb4xLeJHa6cXdzhy7QRmyCyqKxUmPp0tJe
Q79kj8OOLpVep6VeohRu0sI9LJQUGljAX8RlxyPoY4NTHrM5xUb7xLKs1FiGJSE6
3qFJzkF00/MMPZdine1h6OZT3HwAh8qAb0yPaxq64eDa4x4H26Hktjdb7w9HrkcM
4l26RDzLHVwAMuedHWFZwISHOplpzqvEwj3iaaG6SWGV1WOLc+pOCEOXgQccoVkJ
imxbhTcRttVM1U1oRwISX+jfQU2Cw6dovwwV010bYCOsjds2mB3U/c1GFBGYlAQM
8bSmsIVpxwgk58FkNTv4lGXBge8bfNElh8aUxnjbOu5GggGgN4QT29bjcQAmBlp/
M2W84M/hgHcDjKRkCyOTXHRSumUyJvkAoHWxGgiMP6COphgksCjG2Z7m2SNDKx5Y
PewZ5iZFgNPAZUvyNBdFguIOPJXDTVzYdLPIvvgJ1H+aGzXbdWHjhgGlbM5EHDAt
k/MzS/mZZTydFZycQI4K8RVVkmCvi9UuXcLfqkQKqkaYCielmeupjQ6IQRH6Xxfg
bymGmJIuIYYzqkRmxRzsyNVYZH1sH92lm3ddHXd4wyM9q6R2SmWaxsFSODNprlZM
5QoJxmsBDAw4CbPigohnSgZEFq65a8f3cO+6e+FC+fSumttMZDtSHwKUKbtpb3aN
6kgF3T8DuT9Au5U72ZE7NjLn7M2UAWeE0tX1zBHDrGOkigBI3THFv+fLEdLrxg1d
l6Y06vw0youdolOfjheePnuGvy03BtfMpyEIicBlc4t76DfplE1LXlaBnU095bQG
1VE06+DhMMXg7GokZ8HCWDwPrUxcb8+22MrRO2lvH9bazkyOOGAc9j7mJKfWsRz7
BhS37Ah8JV2sffodHFWUbkLondJWX6LuVZw1O33+k9Pnf4Pbly/ePX3xPg3e/VTe
zVA8qTPugOgKmdApvc32YV4h/sSQVpbxgjAn37lhYjkuUT8ilAcAS/YCZP0AFWUk
jhrHjdwydy5keAwm8ec0SvePWBOobCEUHsno6nRTSb+sMLtkKPCLDZ+pVczj6uot
rk5FaRKEcmFFxFPgfdgdWyzT5EuYpPbsGZ5hHaWFTG0/e7baaoT2oLuRNfSPuq+A
TkDdDjpj0GBfXB/oyT13F3RBRKE2D5tQxZS69Y8rWh8rrVn3zVHWXBm7f3RZLxm9
f8yLVTsOp6eYwWADLLTjKiZomRnndDedxWYcD+2jlugqGkOxb2AZB2ed1uLOkDml
36jhMsf+kyq9jBbN7cShVYULBAFLWivZpZNoi4PFR4y0AzeSplLZaOk+gTw+Je6j
9nW99eyZWrLZVWmT42xLuHadbHlzJhFr9EQF9bThwINJhBP2Fma9wQJ423OB6Y9B
DlK+wIhQY6LI6YX+UjFu5fYym8umgkoGKEKhroIEc0AeX2GL9HIOLB/hUdeJ6KS4
DH9pvunSCiZaaBiWxI1W/LsFYtO9x5ISj6lE0p6EFBtOwzWFd4fyCMiqnZtyRJev
uV1nHvlSO9bfgsFzAtAA7w0jwtm6CfiybO/mqtk2xJfrDn16eTUzgC5QGCUoDJgu
sfuxYXAipDQwm85RBmJwXZDBnKYEGXQojVxKzplgOpaht5FjEhbTtZ/ufGnpHMAA
JbOvkHyY1GCgR2mKcH26k55tYiXMHGMBaCoMTOEY+pkzKT74/tezfAl1x+0nbPWW
UiZARVC8qHOsyFBuP8GVkMQNb8FJ2YIwXNBTlrgRzESLlVWqXATlvDy0bqX1z7Xw
0p8ePskBoTcRFZ+jcFo8X9Cs7DHLKcz1px/ol9P22SYA3ZWoNq4xBy0H6HU5j037
TMpli6XR9ByYFcnsKxPcW5ItJqUqLCy84uu5APKTp51c6kPOlM+ik0bq2ihMVpZA
LMcNHW6xdOfu/vJ8RhCaviVuvOgCtfoKAQL/ho4Jj2Dr6m09S33UVRs2Q5l3njjn
2BNPHG4N7L5yH52asowTdGMz5w77o/ELUdZInEbLLCKVBjkazKlsDEjI/UXJ/05R
dXDTl3BsQcDcA0CPet10Vj7Aa7n0zCdkj1goQxhvmUs1H2oa65GAYiiOhXmorcMz
6+6jKWRsXKaof2551UyNItzSY2EUKXXHLIkiMadHT72wAZAMFJKFlBaOIUK6dAl/
0+IL1LK+kX5vc5cxcxQBgJEH1hCeVha6AFtXx8wvvaHLAYqG/sE7P9fNhusEhSoY
+IXPYDWfQA2v7xVq0EOcOrXrLVQb6chAhwHjMeSBkLEtZyB7cBvjMIaKZDzpd+no
LRGlefbsyVNTRESp7bcPRitd2USGlmxjO4t47RRZnQaEOB8BCW4RQDctHgooiZ2w
WE0KMXuQhmecw2JUpsXEqsdoz3wmWsCcd6lApBZLRW78EEjXpQk7Iu46Y3ajvKpg
VKdLZRRH0FFxZx3z0E8Df0vrPv06Pf+QZhSHsodKFEoeuZHaPyIyVhoRYxEqc6o+
F2Y/j1+VdOyIAAf7ziYq3529KU6R3MEzInSLunrIZmeWRrdjotKmEJCbR4Hq8BuP
u0k0khg9nzBSGy5AObpeWEBYiSUs8Mq/pNErqYdUIs/HuzN2sbSk7dJyKr9LlKbS
1jhNg6J79pgwELm2j3d4pJOzMm+KZKgSYE4QPoqC0GaZPUYa+oTOmUtKwWMMFze8
Wc+TON+tZlDsaBqhiSlI5RlrFgeei78p2Zo06tVR88moJ2BM+ab7DhXjNENGjkdX
R+HOEoLjqBXDbTySuYBtEtGQPrbGLDG8CxY8k5hGf/CBiy4JIyu9oYTm/mEK1yHx
PEvuDMnJu8KPqXzwv6iYpTCAZFY4DeeQ2RPUZ+MB1xQQlVfJgEt3OqLSfAouOJmQ
07QNl15TyiaZdpnKaO1TYe4nw9pKxrIdLsHMNNINY7w31GwPk9aP+TAxCUfMeQ2H
DWtOwFJWSplqnV2da6pAVfFfJKFoswzNbcYCzGmlXEBESpA4XwfSzgd0cR+Wdi01
MNrV3VSL7WyOgA36Xl45QadbwQQzYR0uaamA4X6Wxc6Z5HfwxA6T4qn/qQnkIhoW
bEYHWjIfQinGeoUdZUEJczon/pi/PUsKNx51N49KFnxRD5yHSgM/FwiXdU8xY6j1
7FlFfg02uMB3Z5UkKrqzo+TMUO+quWwWgvC5KhiZDCKSxRiZFyafOeAuVH8ClL11
W+pQ3fLLeSqSJW57Xpkpn1WA6RV3oZYw7imlS4z7Bnrt1TXxqewBYJprtcMrnbnh
+xvwaW6cAdHk7sDs9K23cqEFipt4/Lo0eiWbvNQTSeOUWXwVWykiHRPH0GWEUOIK
tTC0+PnIHVBgDTZE5C03XTHQK6E5txs+svndUGiULVIvJXFrttYosraZOlRzI/Ql
LUvD9GqVxRH7fP0FwfuZMM1zg5uD2Q31WZvRYcY2YdOoIyB0xqMGCgewKK/hHCMR
26AauuYoXA1duWFJbySKNkoZSc+PN4ZpnIpFCBiE9CYkHnbJYtdud3NPQWvoG66Z
hsq1PbmvTBrzCS5OvjO2JUvnUGkgZ0FwoEp/cMZkcKD+meEw7SKDkOJjr8tBYvXG
H3p47YQHjEtrsTPTn5mS2DGy2MmMN5GP7SkX82j85hhsCgS5Af9fVjSE9n/+QdPb
uj6jymkmz2p+7O91TuK5lrFzTruYXeFJ3TUWwJatDjpB9I58NOaMRkeZfshNRjb7
hL3hZNaGvJeQ21vJjAtnrnmmDLXKPvv4QxXmj1M0fkr5wDbG6b54ZkGWJ2n/UTmx
mAlaIUcAZiXd1/pyQ3x6rZFKJTeqmZ5xFE0olqMzqpkGz05NZ56VBK/iLVPSQZu8
Fjrr1P/MFP+WzOrzKwIovvH6HG0Azx0vltsJUBQEm++oDZRJrxwlw/CJDS7F6zQz
4vfvvH168jV6aPVr7PzYB2/9CLpJe5i9jnfHsu3IbO+Kiq1kBtJsJSvYNznsD77/
dS3dKGsDvMgiURRECK3GI0B/wirnk9E2ObZ8qirnU53TTC6Mol77F8V2fsUmXDAW
AZA0G90xwtRf6oll22+sXqM/Z98vu5oANx1ze37QAU1NBKuIwXqaucOG33Abdiqi
3DCr9HToPlFm0bvX7exgyTSWd2L4Ta56J1a8MZ/qHCicqxpkAyaN19Nofb4P7uNW
dMPfzeKozhHVZgrquRrSjhi7IBY+aEuanom7sk5xhuE+O2dWw3acLpigSFT4yI4n
4XPaNX4AW5TzlcsIVGOZlpHBxVgLWFXVqjWnAIFtml1Q7WKcKq4/IVybDzNRcgRa
mFcJHT2laAzTjP/OjH8SCX+Ls2SL7KMX2ugNQReeoOhBA3GYVDqV1sNMEPV7N3/s
VEn/pXeN0NTcfG7vhTfRXZI29pE+0patGi6RnjTys1zK6hAde29231RP0WCsBZML
aCUjlYJD29s3fPlYhl/iu2CqOBNNFWh2AsZ7E2N/MZMYPw3MA7Scb8PnL/abRtWl
RAZpDB8rXyClciTFG9RKZRcE0dvgznVB0O9+BHbKD09P3j59/ufUTvnL0+ff5sk3
KmcQEzF8as9tTvN7KJKJmJ3Dqdj915dbUlJ9ejpq/sa5Wr16Fz1X0e2mZldBANha
BPwXTQCqRGZ3s9u6oZiU6cFI8NUvqzblyCsYoLy223Ave28KTmYm5eXSynLVtmrP
yptKPDEgTQpYuAuTd1BTaIlTmkyQbRlx3QgqXrAYrFcQbCZ/unxhUtn7PFKJu7Km
03byopGJ+GVd+80vf653cug4Pnv51ayxvNHiVx/MTQRiuy7zLoFAaiwMZLNdAfoG
HfqOA1OKZyfp8bzDblJxIKj0WEt2bKaTVGxjz90Zn7MxPjMXEUZsQn3qpFGTkSoI
hDwF4/wLhIQafYUe3R4CrV7PNss8r27xVOPsvJA4aVV5NuawW32uSGIA5hFWJ0MU
KX2+VIg5mRC1xaxKk9mqOSUSOOeBkvP4z3MnipzF/+yZ+p35ptPC0Yhijq/s2jIs
jBJI6bGcMzi6z57p7JjG6cmPT0++kS5Z9CveI6VzV7iInao3FuU5vMSxChzDuHS3
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
B64
}

ensure_da_py(){
  local py="$ROOT/DirectoryAssistant.py"
  if [ -f "$py" ]; then
    if grep -Fq 'DA_VERSION = "2026-04-18.3"' "$py" 2>/dev/null; then
      return 0
    fi
    echo "update_py=1"
  else
    echo "write_py=1"
  fi
  da_py_payload | base64 -D 2>/dev/null | gzip -dc >"$py" 2>/dev/null || true
  if [ ! -s "$py" ]; then
    da_py_payload | base64 -d 2>/dev/null | gzip -dc >"$py" 2>/dev/null || true
  fi
  if [ ! -s "$py" ]; then
    echo "write_py_failed=1"
    rm -f "$py" 2>/dev/null || true
    return 1
  fi
  chmod +x "$py" 2>/dev/null || true
  return 0
}

get_info(){
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsS --max-time 1 "http://${HOST}:${PORT}/api/info" 2>/dev/null || true
}

shutdown_srv(){
  command -v curl >/dev/null 2>&1 || return 0
  curl -fsS --max-time 1 -X POST -H "Content-Type: application/json" -d "{}" "http://${HOST}:${PORT}/api/shutdown" >/dev/null 2>&1 || true
}

wait_srv(){
  i=0
  while [ "$i" -lt 25 ]; do
    INFO_JSON="$(get_info)"
    [ -n "$INFO_JSON" ] && return 0
    sleep 0.2
    i=$((i+1))
  done
  return 1
}

step 1
echo "root=$ROOT port=$PORT log=$LOG_FILE"

step 2
INFO_JSON="$(get_info)"
if [ -n "$INFO_JSON" ] && command -v python3 >/dev/null 2>&1; then
  SRV_ROOT="$(printf "%s" "$INFO_JSON" | python3 -B -c 'import sys,json;print(json.load(sys.stdin).get("root_path",""))' 2>/dev/null || true)"
  echo "server_root=$SRV_ROOT"
  if [ -z "$SRV_ROOT" ] || [ "$SRV_ROOT" = "$ROOT" ]; then
    open_url "$URL"
    close_launcher_terminal
    exit 0
  fi
  shutdown_srv
  sleep 1
fi

step 3
rm -f "$PID_FILE" 2>/dev/null || true

step 4
PY="$ROOT/DirectoryAssistant.py"
if ! ensure_da_py; then
  echo "ensure_da_py_failed=1"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3_not_found=1"
  open_url "https://www.python.org/downloads/"
  exit 1
fi
nohup python3 -B "$PY" --root "$ROOT" --bind "$HOST" --port "$PORT" --no-open >/dev/null 2>&1 &

if wait_srv; then
  step 5
  open_url "$URL"
  close_launcher_terminal
  exit 0
fi

step 9
echo "failed_to_start=1"
exit 1
