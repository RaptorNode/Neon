<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<meta name="description" content="">
		<meta name="author" content="">
		
		<title>Neon Login</title>
		<link href="templates/default/css/bootstrap.css" rel="stylesheet">
		<link href="templates/default/css/login.css" rel="stylesheet">
	</head>
	<body>
		<div class="container">
			<div class="row">
				<div class="col-sm-6 col-md-4 col-md-offset-4">
					<h1 class="text-center login-title">Sign in to Neon</h1>
					<div class="account-wall">
						<form class="form-signin" name="login" action="index.php?id=login" method="post">
							{%if isset|Errors == true}
								<div class="alert alert-danger">{%?Errors[result]}</div>
							{%/if}
							<input type="text" class="form-control" placeholder="Username" name="username" required autofocus>
							<input type="password" class="form-control" placeholder="Password" name="password" required>
							<button class="btn btn-lg btn-primary btn-block" type="submit">Sign in</button>
							<label class="checkbox pull-left">
								<input type="checkbox" value="1" name="remember">
								Remember me
							</label>
							<a href="#" class="pull-right need-help">Forgot Password? </a><span class="clearfix"></span>
						</form>
					</div>
				</div>
			</div>
		</div>
	</body>
</html>
	