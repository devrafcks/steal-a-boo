// Gera as imagens da loja Roblox (ícone do jogo, capas e ícones de produtos)
// a partir das fotos do jogo em assets/store/src, usando o Edge em modo headless.
// Uso: node tools/store-art/build.js
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..", "..");
const OUT = path.join(ROOT, "assets", "store");
const SRC = path.join(OUT, "src");
const TMP = path.join(OUT, ".html");
fs.mkdirSync(TMP, { recursive: true });

const EDGE = [
	"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
	"C:/Program Files/Microsoft/Edge/Application/msedge.exe",
].find((p) => fs.existsSync(p));
if (!EDGE) throw new Error("Microsoft Edge não encontrado");

const FONTS = `<link href="https://fonts.googleapis.com/css2?family=Luckiest+Guy&family=Fredoka:wght@600;700&display=block" rel="stylesheet">`;
const img = (name) => "file:///" + path.join(SRC, name).replace(/\\/g, "/");

function render(name, w, h, body, css) {
	const html = `<!doctype html><html><head><meta charset="utf-8">${FONTS}<style>
	*{margin:0;padding:0;box-sizing:border-box}
	html,body{width:${w}px;height:${h}px;overflow:hidden;background:#2a1650}
	.title{font-family:'Luckiest Guy',sans-serif;color:#fff;letter-spacing:2px;
		background:linear-gradient(90deg,#ff7ac8,#ffd84a 50%,#5ad8ff);-webkit-background-clip:text;background-clip:text;color:transparent;
		filter:drop-shadow(0 6px 0 #2a1650) drop-shadow(0 0 18px rgba(255,120,200,.55));}
	.stroke{-webkit-text-stroke:10px #2a1650;paint-order:stroke fill}
	.tag{font-family:'Fredoka',sans-serif;font-weight:700;color:#fff;text-shadow:0 4px 0 #2a1650,0 0 14px rgba(0,0,0,.6)}
	${css}</style></head><body>${body}</body></html>`;
	const file = path.join(TMP, name + ".html");
	fs.writeFileSync(file, html);
	const out = path.join(OUT, name + ".png");
	execFileSync(EDGE, [
		"--headless=new",
		"--disable-gpu",
		"--hide-scrollbars",
		"--force-device-scale-factor=1",
		"--virtual-time-budget=6000",
		`--window-size=${w},${h}`,
		`--screenshot=${out}`,
		"file:///" + file.replace(/\\/g, "/"),
	], { stdio: "ignore" });
	console.log("ok", path.relative(ROOT, out));
}

// Título com contorno (duas camadas: contorno escuro + gradiente)
const title = (text, size) => `<div style="position:relative;font-size:${size}px;line-height:1">
	<div class="title" style="position:absolute;inset:0;-webkit-text-stroke:${Math.round(size / 7)}px #2a1650;color:#2a1650;background:none;filter:none">${text}</div>
	<div class="title" style="position:relative">${text}</div></div>`;

// ---------- Ícone do jogo 512x512 ----------
render("icon", 512, 512, `
	<div style="position:absolute;inset:0;background:url('${img("trio.png")}') center/cover;transform:scale(1.25);transform-origin:50% 42%"></div>
	<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 40%,transparent 45%,rgba(42,22,80,.75))"></div>
	<div style="position:absolute;left:0;right:0;bottom:26px;display:flex;flex-direction:column;align-items:center;gap:0">
		${title("STEAL", 92)}${title("A BOO!", 92)}
	</div>`, "");

// ---------- Capas 1920x1080 ----------
const thumbs = [
	["thumb1", "lineup.png", "16 BOOS PARA COLECIONAR!", "50% 40%"],
	["thumb2", "base.png", "CONSTRUA ATÉ 4 ANDARES", "50% 45%"],
	["thumb3", "overview.png", "ROUBE, DEFENDA E FIQUE RICO!", "50% 55%"],
];
for (const [name, src, tag, pos] of thumbs) {
	render(name, 1920, 1080, `
		<div style="position:absolute;inset:0;background:url('${img(src)}') ${pos}/cover"></div>
		<div style="position:absolute;inset:0;background:linear-gradient(180deg,rgba(42,22,80,.0) 45%,rgba(42,22,80,.85))"></div>
		<div style="position:absolute;left:70px;top:50px">${title("STEAL A BOO!", 150)}</div>
		<div class="tag" style="position:absolute;left:0;right:0;bottom:70px;text-align:center;font-size:96px">${tag}</div>`, "");
}

// ---------- Ícones de produtos e passes 512x512 ----------
const TAB_COLORS = {
	Boosts: ["#3ccf8e", "#1b7a52"],
	Poderes: ["#46c8ff", "#1f5fb0"],
	Sustos: ["#ff6fb5", "#9b2f8a"],
	Cash: ["#ffd84a", "#d08a10"],
	Passes: ["#b98bff", "#5b2fb8"],
};
// Lê o Config.luau só para pegar ícone/nome/aba de cada item
const config = fs.readFileSync(path.join(ROOT, "src", "shared", "Config.luau"), "utf8");
function items(section) {
	const start = config.indexOf(`\t${section} = {`);
	const end = config.indexOf("\n\t},", start);
	const block = config.slice(start, end);
	const re = /\t\t(\w+) = \{([^}]*)\}/g;
	const list = [];
	let m;
	while ((m = re.exec(block))) {
		const body = m[2];
		const get = (k) => (body.match(new RegExp(k + '\\s*=\\s*"([^"]*)"')) || [])[1];
		const num = (k) => Number((body.match(new RegExp(k + "\\s*=\\s*(\\d+)")) || [])[1]);
		list.push({ key: m[1], name: get("name"), icon: get("icon"), tab: get("tab") || "Passes", price: num("price"), mult: num("mult"), amount: num("amount") });
	}
	return list;
}
const all = [...items("Products"), ...items("GamePasses")];
fs.writeFileSync(path.join(OUT, "items.json"), JSON.stringify(all, null, 2));
for (const it of all) {
	const [c1, c2] = TAB_COLORS[it.tab] || TAB_COLORS.Passes;
	let badge = "";
	if (it.mult) badge = `${it.mult}x`;
	else if (it.tab === "Cash" && it.amount) badge = "+" + (it.amount >= 1000 ? it.amount / 1000 + "K" : it.amount);
	else if (it.amount && it.amount > 1) badge = `x${it.amount}`;
	render("product_" + it.key, 512, 512, `
		<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 35%,${c1},${c2})"></div>
		<div style="position:absolute;inset:0;background:repeating-conic-gradient(from 0deg at 50% 45%,rgba(255,255,255,.10) 0 10deg,transparent 10deg 20deg)"></div>
		<div style="position:absolute;inset:18px;border:10px solid rgba(255,255,255,.85);border-radius:64px"></div>
		<div style="position:absolute;left:0;right:0;top:70px;text-align:center;font-size:250px;line-height:1;filter:drop-shadow(0 12px 0 rgba(0,0,0,.25))">${it.icon}</div>
		${badge ? `<div style="position:absolute;right:46px;top:44px">${title(badge, 110)}</div>` : ""}`, "");
}
console.log("total produtos/passes:", all.length);
