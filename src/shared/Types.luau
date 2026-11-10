--[[ Types.luau — tipos usados por mais de um módulo ]]

export type BooDef = {
	name: string,
	rarity: string,
	incomePerSec: number,
	zone: string,
	weight: number,
	color: Color3,
	accessory: string,
}

export type Snapshot = {
	Cash: number,
	TotalCash: number,
	Rebirths: number,
	Speed: number,
	ThrowPower: number,
	IncomePerSec: number,
	Inventory: { [string]: number },
	PlotLayout: { [string]: string },
	Consumables: { [string]: number },
	LuckyCaptures: number,
	SlotCount: number,
	RebirthCost: number,
	TrainCost: { Speed: number, Throw: number },
	Passes: { [string]: boolean },
	Settings: { ReduceScares: boolean, MusicVolume: number },
	Daily: { streak: number, canClaim: boolean, nextReward: number },
	Cash2xEnds: number,
	CarouselPrice: number,
	PlotIndex: number?,
}

return {}
