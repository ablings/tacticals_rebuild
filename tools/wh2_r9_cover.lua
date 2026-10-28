-- client step (round 9): cover still works on the retinted olive crates C03 / C04 (C01 = an untinted tall crate, control)
for _, c in { { "C03 olive", -31, -29, -31, -23 }, { "C04 olive", 31, 29, 31, 23 }, { "C01 control", -5, -11, -5, -8 } } do
	place(c[2], c[3], 0, c[4] - c[2], c[5] - c[3])
	walkTo(c[4], c[5] - (c[5] > c[3] and 2.2 or -2.2), 3)
	log(string.format("cover %-12s %s %s", c[1], fmt(act("Cover", c[4], c[5], 2)), where()))
	act("Cover")
	waitIdle(2)
end
return table.concat(LOG, "\n")
