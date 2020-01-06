# Requirements

- http-server `yarn global add http-server`
- websocketd `brew install websocketd`
- Haskell Stack `curl -sSL https://get.haskellstack.org/ | sh` or `brew install haskell-stack`

# Usage

- Terminal 1 `http-server .`
- Terminal 2 `websocketd --port=8080 tail -n +1 -f perf.txt`
- Terminal 3 `./script.hs`
- Browser: http://localhost:8081/ (and refresh it whenever you kill/restart `./script.hs`)

# perf.txt

perf.txt is a multi-line plot:

- axes: [x, y1, y2]
- description: [distance from target commit, query time (ms), query time (ms)]
- example: [2,40,30]
