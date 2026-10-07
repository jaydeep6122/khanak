import { Router } from "express";

/**
 * Terms, privacy policy and how to delete an account, as plain web pages. The
 * app opens them in the browser, and the Play Store links to them, so they
 * need no sign-in and still answer during maintenance.
 */

const UPDATED_ON = "7 October 2026";

/** Digits only, e.g. "919876543210", or null when SUPPORT_WHATSAPP is unset. */
export const supportWhatsApp = () => {
  const digits = (process.env.SUPPORT_WHATSAPP || "").replace(/\D/g, "");
  return digits.length >= 10 ? digits : null;
};

const contactLine = () => {
  const number = supportWhatsApp();
  return number
    ? `on WhatsApp at <a href="https://wa.me/${number}">+${number}</a>`
    : "through Help → Contact us in the app";
};

const page = (title, body) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · Khanak</title>
<style>
  :root { color-scheme: light dark; --ink: #1c1917; --muted: #57534e; --bg: #fafaf9; --accent: #c2410c; }
  @media (prefers-color-scheme: dark) { :root { --ink: #f5f5f4; --muted: #a8a29e; --bg: #1c1917; --accent: #fb923c; } }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 16px/1.6 system-ui, sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 24px 16px 64px; }
  h1 { font-size: 1.6rem; margin-bottom: 0; }
  h2 { font-size: 1.15rem; margin-top: 2rem; }
  .updated { color: var(--muted); margin-top: 4px; }
  a { color: var(--accent); }
  li { margin: 4px 0; }
</style>
</head>
<body><main>
<h1>${title}</h1>
<p class="updated">Last updated ${UPDATED_ON}</p>
${body}
</main></body>
</html>`;

const terms = () =>
  page(
    "Terms of Use",
    `
<p>Khanak is an app for keeping the accounts of a brick kiln: workers and their pay, advances, brick counts and stock, sales, trucks and expenses. It is a private project run from India. By creating an account or using the app you agree to these terms.</p>

<h2>Your account</h2>
<ul>
  <li>Give your real name and an email address you can use. Keep your password to yourself; you are responsible for what is done with your account.</li>
  <li>The owner of a factory decides who else (munim, supervisor) can use it and what they can do. The owner is responsible for the people they add.</li>
  <li>You may delete your account at any time from the app (More → Profile → Delete account).</li>
</ul>

<h2>Your data and your books</h2>
<ul>
  <li>Everything you type in (workers, pay, advances, sales, customers, suppliers and so on) is yours. You must have the right to record it, including other people's names and phone numbers.</li>
  <li>Khanak calculates balances, pay and stock from what you enter. Check the figures before you pay anyone or settle an account. Khanak is a record-keeping tool, not accounting, tax or legal advice.</li>
  <li>Do not use Khanak for anything unlawful, to harm anyone, or to try to reach data that is not yours.</li>
</ul>

<h2>Subscription</h2>
<p>A factory may need a running subscription to add or change entries. Without one, its books can still be read. Prices and plans are shown before you pay.</p>

<h2>The service</h2>
<ul>
  <li>Khanak is provided as it is. We work to keep it running and your data safe, but we cannot promise it will always be available or free of mistakes.</li>
  <li>As far as the law allows, we are not liable for any loss that comes from using the app, including losses from wrong entries, missed payments or the service being unavailable.</li>
  <li>We may suspend an account that breaks these terms. We may change these terms; the date above shows the latest version, and using the app after a change means you accept it.</li>
</ul>

<h2>Law</h2>
<p>These terms are governed by the laws of India.</p>

<h2>Contact</h2>
<p>Questions about these terms: reach us ${contactLine()}.</p>
<p>See also the <a href="privacy">Privacy Policy</a>.</p>
`,
  );

const privacy = () =>
  page(
    "Privacy Policy",
    `
<p>This policy explains what Khanak collects, why, and what you can do about it. Khanak is a private project run from India and follows the Information Technology Act, 2000 and the Digital Personal Data Protection Act, 2023.</p>

<h2>What we collect</h2>
<ul>
  <li><strong>Your account:</strong> name, email address, phone number (if you give one) and your password, which is stored only as a secure hash.</li>
  <li><strong>What you enter for your factory:</strong> workers' names, nicknames, villages and phone numbers, their work, pay, advances and balances; customers and suppliers; sales, expenses, trucks and stock.</li>
  <li><strong>Sign-in and security details:</strong> the device description your app sends when you sign in, the IP address of password reset requests, and a record of who created, changed or cancelled each entry.</li>
</ul>
<p>The app does not use advertising, analytics or tracking, and does not read your contacts, location, photos or files.</p>

<h2>Why we use it</h2>
<ul>
  <li>To run the app: sign you in, keep your factory's books, and calculate pay, balances and stock.</li>
  <li>To keep accounts safe: detect misuse and send password reset codes by email.</li>
  <li>To show a worker their own account when the owner shares that worker's link.</li>
</ul>
<p>We do not sell your data or share it for marketing.</p>

<h2>Who can see it</h2>
<ul>
  <li>People you add to your factory, according to their role (owner, munim, supervisor).</li>
  <li>A worker, through their own link, sees only their own account. The owner can switch the link off or replace it.</li>
  <li>The services we run on: our database host (Supabase), our server host, and our email provider, only to provide the service.</li>
  <li>Authorities, when the law requires it.</li>
</ul>

<h2>How long we keep it</h2>
<p>Your factory's books are kept while your account is open, because accounts depend on past entries. When you delete your account, your name, email and phone are erased from it and you are signed out everywhere. Factories you own are closed for everyone. Their entries stay on our servers, not visible to anyone, as part of the books they belong to, unless you ask us to erase them.</p>

<h2>Your rights</h2>
<p>You can see and correct your details in the app, delete your account from the app, and ask us to access, correct or erase your personal data, or raise a complaint, ${contactLine()}. If you are a worker or customer recorded by a factory, please contact that factory's owner first; we will help if they cannot.</p>

<h2>Security</h2>
<p>Data travels over HTTPS, passwords are hashed, and the database can be reached only through our server. No system is perfectly secure, so please keep your password private.</p>

<h2>Children</h2>
<p>Khanak is meant for adults who run or work for a kiln. Do not create an account if you are under 18.</p>

<h2>Changes</h2>
<p>We may update this policy. The date above shows the latest version.</p>

<h2>Contact</h2>
<p>Reach us ${contactLine()}. See also the <a href="terms">Terms of Use</a> and <a href="delete-account">how to delete your account</a>.</p>
`,
  );

const deleteAccount = () =>
  page(
    "Delete your Khanak account",
    `
<p>You can delete your account yourself, from the app:</p>
<ol>
  <li>Open Khanak and go to <strong>More</strong>.</li>
  <li>Tap <strong>Profile</strong>.</li>
  <li>Tap <strong>Delete account</strong>, type your password and confirm.</li>
</ol>

<h2>What happens</h2>
<ul>
  <li>Your name, email address and phone number are erased, your password stops working and you are signed out on every device.</li>
  <li>Every factory you own is closed, for you and for the munims and supervisors you added.</li>
  <li>You are removed from any factory someone else added you to. That factory's books stay with its owner.</li>
  <li>Entries in the books (pay, advances, sales and so on) are kept, without your details, because the books depend on them.</li>
</ul>
<p>This cannot be undone. You may sign up again with the same email later, as a new account.</p>

<h2>Can't open the app?</h2>
<p>Contact us ${contactLine()} from the phone number or email of your account, and we will delete it for you. You can also ask us to erase your factories' entries entirely.</p>
`,
  );

const router = Router();

const send = (render) => (req, res) => {
  res.type("html").set("Cache-Control", "public, max-age=3600").send(render());
};

router.get("/terms", send(terms));
router.get("/privacy", send(privacy));
router.get("/delete-account", send(deleteAccount));

export default router;
