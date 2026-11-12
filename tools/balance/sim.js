const fs = require("fs");
const path = require("path");

const src = fs.readFileSync(path.join(__dirname, "..", "..", "src", "shared", "Config.luau"), "utf8");
const num = (re, def) => {
	const m = src.match(re);
	return m ? Number(m[1]) : def;
};

const E = {
	start: num(/StartingCash = (\d+)/),
	trainBase: num(/TrainingCashCostBase = (\d+)/),
	trainGrowth: num(/TrainingCostGrowth = ([\d.]+)/),
	speedPer: num(/SpeedPerTrain = ([\d.]+)/),
	throwPer: num(/ThrowPerTrain = ([\d.]+)/),
	maxSpeed: num(/MaxSpeed = (\d+)/) - num(/BaseWalkSpeed = (\d+)/),
	maxThrow: num(/MaxThrow = (\d+)/),
	sell: num(/SellMultiplier = (\d+)/),
};
const rebirth = { base: num(/CashRequiredBase = (\d+)/), growth: num(/CashRequiredGrowth = ([\d.]+)/) };
const floors = [...src.matchAll(/\{ name = "[^"]*andar", cost = (\d+) \}/g)].map((m) => Number(m[1]));
floors.unshift(0); // térreo
// pega "Nome = { ... }" (uma ou várias linhas) e lê os números do bloco
const block = (name) => {
	const i = src.indexOf(name + " = {");
	if (i < 0) throw new Error("bloco não encontrado: " + name);
	return src.slice(i, src.indexOf("}", i));
};
const field = (b, key) => {
	const m = b.match(new RegExp("\\b" + key + " = ([\\d.]+)"));
	return m ? Number(m[1]) : 0;
};
const ped = (() => {
	const b = block("Pedestal");
	return { max: field(b, "max"), per: field(b, "perLevel"), base: field(b, "baseCost"), growth: field(b, "growth") };
})();
const trackDef = (name) => {
	const b = block(name);
	return { max: field(b, "max"), per: field(b, "perLevel"), base: field(b, "baseCost"), growth: field(b, "growth") };
};
const incomeTrack = trackDef("Income");
const baseSlots = num(/BaseGroundSlots = (\d+)/);
const floorSlots = num(/FloorSlots = (\d+)/);

const boos = [...src.matchAll(/(\w+) = \{\s*name = "\w+",\s*rarity = "(\w+)",\s*incomePerSec = (\d+),\s*zone = "(\w+)",\s*weight = (\d+)/g)].map((m) => ({
	key: m[1],
	rarity: m[2],
	income: +m[3],
	zone: m[4],
	weight: +m[5],
}));
const zones = [...src.matchAll(/\{\s*name = "(\w+)",\s*label = "[^"]*",\s*minStat = (\d+)/g)].map((m) => ({ name: m[1], minStat: +m[2] }));
if (!boos.length || !zones.length || floors.length < 2) throw new Error("não consegui ler o Config (boos/zonas/andares)");

const hours = Number(process.argv[2]) || 60;
const STEP = 10;
let seed = 12345;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296);

const s = {
	t: 0,
	cash: E.start,
	total: 0,
	speed: 0,
	throw: 0,
	speedTrains: 0,
	throwTrains: 0,
	floor: 1,
	slots: [{ boo: boos.find((b) => b.key === "MarshBoo") || boos[0], ped: 1 }],
	incomeLevel: 0,
	pedBought: 0,
	trackBought: 0,
};
const milestones = [];
const done = new Set();
const mark = (name) => {
	if (!done.has(name)) {
		done.add(name);
		milestones.push([s.t / 3600, name]);
	}
};

const maxSlots = () => baseSlots + (s.floor - 1) * floorSlots;
const stat = () => Math.max(s.speed, s.throw);
const incomeNow = () => s.slots.reduce((a, sl) => a + sl.boo.income * (1 + ped.per * (sl.ped - 1)), 0) * (1 + incomeTrack.per * s.incomeLevel);
const trainCost = (n) => E.trainBase * Math.pow(E.trainGrowth, n);
const nextZone = () => zones.filter((z) => z.minStat > stat()).sort((a, b) => a.minStat - b.minStat)[0];
const bestZone = () => zones.filter((z) => z.minStat <= stat()).sort((a, b) => b.minStat - a.minStat)[0];

function capture() {
	const z = bestZone();
	const pool = boos.filter((b) => b.zone === z.name);
	const total = pool.reduce((a, b) => a + b.weight, 0);
	let r = rnd() * total;
	let pick = pool[pool.length - 1];
	for (const b of pool) {
		r -= b.weight;
		if (r <= 0) {
			pick = b;
			break;
		}
	}
	if (s.slots.length < maxSlots()) {
		s.slots.push({ boo: pick, ped: 1 });
	} else {

		s.slots.sort((a, b) => a.boo.income - b.boo.income);
		if (pick.income > s.slots[0].boo.income) {
			s.cash += s.slots[0].boo.income * E.sell;
			s.slots[0].boo = pick;
		} else {
			s.cash += pick.income * E.sell;
		}
	}
	if (pick.rarity === "Secret") mark("1º Boo Secreto");
	if (pick.rarity === "Mythic") mark("1º Boo Mítico");
	if (pick.rarity === "Legendary") mark("1º Boo Lendário");
}

function options() {
	const out = [];
	const inc = incomeNow();
	const base = s.slots.reduce((a, sl) => a + sl.boo.income, 0);

	if (s.floor < floors.length) {
		const avg = s.slots.length ? base / s.slots.length : 1;
		out.push({ kind: "floor", cost: floors[s.floor], gain: floorSlots * avg * (1 + incomeTrack.per * s.incomeLevel) * 0.6 });
	}

	const cand = s.slots.filter((sl) => sl.ped < ped.max).sort((a, b) => b.boo.income / (1 + ped.per * (b.ped - 1)) - a.boo.income / (1 + ped.per * (a.ped - 1)))[0];
	if (cand) out.push({ kind: "ped", cost: ped.base * Math.pow(ped.growth, cand.ped - 1), gain: cand.boo.income * ped.per * (1 + incomeTrack.per * s.incomeLevel), cand });

	if (s.incomeLevel < incomeTrack.max) out.push({ kind: "income", cost: incomeTrack.base * Math.pow(incomeTrack.growth, s.incomeLevel), gain: base * incomeTrack.per });
	return out.filter((o) => o.gain > 0).map((o) => ({ ...o, payback: o.cost / (o.gain || 1e-9) }));
}

function spend() {
	let bought = true;
	let guard = 0;
	while (bought && guard++ < 50) {
		bought = false;
		const z = nextZone();

		if (z && z.minStat > 0) {
			const useSpeed = s.speed < E.maxSpeed && (s.throw >= E.maxThrow || trainCost(s.speedTrains) <= trainCost(s.throwTrains) || z.minStat <= E.maxSpeed);
			const c = useSpeed ? trainCost(s.speedTrains) : trainCost(s.throwTrains);
			if (c <= s.cash * 0.3 || c <= s.cash && incomeNow() * 600 < c) {
				if (c <= s.cash) {
					s.cash -= c;
					if (useSpeed) { s.speed += E.speedPer; s.speedTrains++; } else { s.throw += E.throwPer; s.throwTrains++; }
					bought = true;
					continue;
				}
			}
		}
		const opts = options().filter((o) => o.cost <= s.cash && (o.kind === "floor" || o.payback < 7200)).sort((a, b) => a.payback - b.payback);
		if (opts.length) {
			const o = opts[0];
			s.cash -= o.cost;
			if (o.kind === "floor") { s.floor++; mark(`${s.floor}º andar`); }
			if (o.kind === "ped") { o.cand.ped++; s.pedBought++; }
			if (o.kind === "income") { s.incomeLevel++; s.trackBought++; if (s.incomeLevel === incomeTrack.max) mark("Gerador no máximo"); }
			bought = true;
		}
	}
}

let nextReb = 0;
for (s.t = 0; s.t < hours * 3600; s.t += STEP) {
	const inc = incomeNow();
	s.cash += inc * STEP;
	s.total += inc * STEP;
	if (Math.floor(s.t / STEP) % 4 === 0 && rnd() < 0.6) capture();
	spend();
	const z = stat();
	if (z >= 8) mark("Corredor das Barracas liberado (stat 8)");
	if (z >= 16) mark("Terreno da Lua liberado (stat 16)");
	if (z >= 30) mark("Tenda Secreta liberada (stat 30)");
	if (s.speed >= E.maxSpeed) mark("Speed no máximo");
	if (s.slots.length >= 10) mark("10 Boos na base");
	if (s.slots.every((sl) => sl.ped >= 5) && s.slots.length >= 6) mark("todos os pedestais no nível 5");
	if (s.total >= rebirth.base * Math.pow(rebirth.growth, nextReb)) { if (nextReb < 6) mark(`ganhou o suficiente para o Rebirth ${nextReb + 1}`); nextReb++; }
	if (Math.floor(s.t / 3600) !== Math.floor((s.t - STEP) / 3600) && process.argv.includes("--steps")) {
		console.log(`${(s.t / 3600).toFixed(0).padStart(3)}h renda ${inc.toFixed(0).padStart(9)}/s  cash ${s.cash.toFixed(0).padStart(12)}  andar ${s.floor}  boos ${s.slots.length}  stat ${z.toFixed(1)}`);
	}
}
const f = (h) => (h < 1 ? `${Math.round(h * 60)} min` : `${h.toFixed(1)} h`);
console.log(`\nJogador gratuito ativo, ${hours}h simuladas:`);
for (const [h, name] of milestones) console.log(`  ${f(h).padStart(8)}  ${name}`);
console.log(`\nFim: renda ${incomeNow().toFixed(0)}/s | andar ${s.floor}/${floors.length} | ${s.slots.length} Boos | stat ${stat().toFixed(1)} | pedestais comprados ${s.pedBought} | Gerador ${s.incomeLevel}/${incomeTrack.max}`);
