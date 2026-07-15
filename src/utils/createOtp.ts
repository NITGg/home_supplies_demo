export const createOtp = (otpLength: number = 6) => {
  let otp = "";
  const digits = "0123456789";
  for (let i = 0; i < otpLength; i++) {
    otp += digits[Math.floor(Math.random() * digits.length)];
  }
  return otp;
};
