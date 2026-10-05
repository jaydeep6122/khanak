// Every factory is in India, so "today" is always the date in IST, whatever
// timezone the server runs in.
const IST = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Kolkata",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

/** 'YYYY-MM-DD' of `at` (default now) in IST. */
export const istDate = (at = new Date()) => IST.format(at);

export const todayIst = () => istDate();
