package services

import "testing"

// Calendar anchors used below (June 2024): 2024-06-10 = Monday, -11 = Tuesday,
// -14 = Friday, -15 = Saturday, -17 = the following Monday.
func dt(date string, h, m int) tomtomDateTime {
	return tomtomDateTime{Date: date, Hour: h, Minute: m}
}
func tr(sd string, sh, sm int, ed string, eh, em int) tomtomTimeRange {
	return tomtomTimeRange{StartTime: dt(sd, sh, sm), EndTime: dt(ed, eh, em)}
}

func TestTomTomHoursToOSM(t *testing.T) {
	cases := []struct {
		name   string
		ranges []tomtomTimeRange
		want   string
	}{
		{
			name:   "empty -> no string (honest: no badge)",
			ranges: nil,
			want:   "",
		},
		{
			name: "per-day ranges in Mon..Sun order",
			ranges: []tomtomTimeRange{
				tr("2024-06-11", 9, 0, "2024-06-11", 22, 0), // Tue (out of order on purpose)
				tr("2024-06-10", 9, 0, "2024-06-10", 22, 0), // Mon
			},
			want: "Mo 09:00-22:00; Tu 09:00-22:00",
		},
		{
			name: "overnight range becomes a wrap (bar)",
			ranges: []tomtomTimeRange{
				tr("2024-06-14", 21, 0, "2024-06-15", 4, 0), // Fri 21:00 -> Sat 04:00
			},
			want: "Fr 21:00-04:00",
		},
		{
			name: "split shift on one day is comma-joined",
			ranges: []tomtomTimeRange{
				tr("2024-06-10", 10, 0, "2024-06-10", 14, 0),
				tr("2024-06-10", 17, 0, "2024-06-10", 22, 30),
			},
			want: "Mo 10:00-14:00,17:00-22:30",
		},
		{
			name: "same weekday recurring across the 7-day window is deduped",
			ranges: []tomtomTimeRange{
				tr("2024-06-10", 9, 0, "2024-06-10", 22, 0), // Mon
				tr("2024-06-17", 9, 0, "2024-06-17", 22, 0), // next Mon, same span
			},
			want: "Mo 09:00-22:00",
		},
		{
			name: "unparseable date is skipped",
			ranges: []tomtomTimeRange{
				tr("not-a-date", 9, 0, "not-a-date", 22, 0),
				tr("2024-06-10", 8, 0, "2024-06-10", 20, 0), // Mon
			},
			want: "Mo 08:00-20:00",
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := tomtomHoursToOSM(c.ranges); got != c.want {
				t.Fatalf("tomtomHoursToOSM() = %q, want %q", got, c.want)
			}
		})
	}
}
