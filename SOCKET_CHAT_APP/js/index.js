const baseURL = "https://tawreedat.nitg-eg.com/courier_apis/api/v1/courier";

$("#login").click(() => {
  const phone = $("#email").val(); // Since your system might use phone for supplier login, or maybe email.
  const password = $("#password").val();
  const data = {
    phone: phone,
    password,
  };

  axios({
    method: "post",
    url: `${baseURL}/auth/login`,
    data: data,
    headers: { "Content-Type": "application/json; charset=UTF-8" },
  })
    .then(function (response) {
      console.log(response);
      const resData = response.data.data || response.data.result;

      const token = resData?.accessToken || resData?.token;

      if (token) {
        localStorage.setItem("token", token);
        window.location.href = "chat.html";
      } else {
        console.log("In-valid credentials or response structure changed");
        alert("Login successful but token not found in response.");
      }
    })
    .catch(function (error) {
      console.log(error);
      alert(
        "Login failed: " + (error.response?.data?.message || error.message),
      );
    });
});
