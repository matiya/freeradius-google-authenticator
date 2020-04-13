---
title: freeradius + google authenticator
---

For demo purposes I needed a quick way to deploy freeradius w/Google Authenticator.

I based this container on the *freeradius-django* as described here: https://github.com/2stacks/freeradius-django

Instructions for Authentication Integration were taken from here:
https://networkjutsu.com/freeradius-with-two-factor-authentication/
    
## Instructions

::: {.tip}
There are three containers in docker-compose.yml

freeradius
:   contains freeradius server and the authentication module for google
    google

postgres
:   contains config and users

django
:   admin interface plus a couple of utils to create users and a rest interface to postgres
:::

1.  Clone this repo

        git clone --recurse-submodules git@github.com:matiya/freeradius-google-authenticator.git
        cd freeradius-google-authenticator

2.  Pull and build the docker images

        docker-compose build --pull

3.  Edit the django config file

        cp ./django-freeradius/tests/local_settings.example.py ./django-freeradius/tests/local_settings.py

    ``` {.python}
    # ./django-freeradius/tests/local_settings.py

    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql_psycopg2',
            'NAME': 'radius',
            'USER': 'debug',
            'PASSWORD': 'debug',
            'HOST': 'postgres',
            'PORT': '5432',
            'OPTIONS': {'sslmode': 'require'},
        },
    }

    ALLOWED_HOSTS = ['*']
    ```

4.  Set the right permissions, otherwise postgres complains

        sudo chown root:70 ./certs/postgres/*
        sudo chmod 644 ./certs/postgres/*.crt
        sudo chmod 640 ./certs/postgres/*.key

5.  Run the containers

        docker-compose up
        docker-compose ps

    ::: {.tip}
    The following output indicates that the containers are running

    ``` {.example}
    freeradius    | Listening on auth address 127.0.0.1 port 18120 bound to server inner-tunnel
    freeradius    | Listening on proxy address * port 44768
    freeradius    | Listening on proxy address :: port 53634
    freeradius    | Ready to process requests
    ```

    If an error message indicates that something is wrong with postgres
    it could be bad schema initialization.
    Run:
    `docker volume rm radius-gauth_postgres_data`
    :::

6.  Create testing users

        # Create admin user
        docker-compose run --rm django python manage.py createsuperuser
        # Create one or several common users
        docker-compose run --rm -v $PWD/scripts/users.csv:/users.csv django python manage.py batch_add_users --name users --file /users.csv

7.  Test the authentication from a docker container

        docker exec -it freeradius radtest root pass.123 freeradius 0 testing123

    Where `root` and `pass.123` are user and password of the admin user
    created with the script `createsuperuser`

8.  Try radius from any pc with the package
    `freeradius`

        radtest root pass.123 <ip-container> 0 testing123

9.  Create a linux user to test google-authenticator OTP authentication

        docker exec -it freeradius useradd -m user1
        docker exec -it freeradius passwd user1

10. Link the account with google-authenticator

        docker exec --user=user1 -it google-authenticator

    This will open a config dialog

    ::: {.tip}
    There are three config options:
    -   (app) Scan the QR code with a cellphone
    -   (app) Input the secret key to the application
    -   (no app) Use the emergency code. **Warning**:
        Be aware that these codes can't be reused
    :::

    ``` {.example}
    Do you want authentication tokens to be time-based (y/n) y
    <QR code>
    Your new secret key is: <secret key>
    Your emergency scratch codes are:
    <one use emergency codes>

    Do you want me to update your "/home/user1/.google_authenticator" file? (y/n) y   

    Do you want to disallow multiple uses of the same authentication
    token? This restricts you to one login about every 30s, but it increases
    your chances to notice or even prevent man-in-the-middle attacks (y/n) n

    By default, a new token is generated every 30 seconds by the mobile app.
    In order to compensate for possible time-skew between the client and the server,
    we allow an extra token before and after the current time. This allows for a
    time skew of up to 30 seconds between authentication server and client. If you
    experience problems with poor time synchronization, you can increase the window
    from its default size of 3 permitted codes (one previous code, the current
    code, the next code) to 17 permitted codes (the 8 previous codes, the current
    code, and the 8 next codes). This will permit for a time skew of up to 4 minutes
    between client and server.
    Do you want to do so? (y/n) y

    If the computer that you are logging into isn't hardened against brute-force
    login attempts, you can enable rate-limiting for the authentication module.
    By default, this limits attackers to no more than 3 login attempts every 30s.
    Do you want to enable rate-limiting? (y/n) n
    ```

11. With any config option the following command should authenticate the linux user

        docker exec -it freeradius radtest user1 pass.123abcd123 localhost 0 testing123 

    Where:

    user1

    :   Is the linux user created in step 9

    pass.123

    :   is the linux password of  `user1`

    abcd123

    :   is either the token obtained in the Google Authenticator app or 
        an emergency code

    A successful authentication should output:

    ``` {.example}
    Sent Access-Request Id 132 from 0.0.0.0:47938 to 127.0.0.1:1812 length 75
    User-Name = "user1"
    User-Password = "pass.123abcd123"
    NAS-IP-Address = 192.168.1.100
    NAS-Port = 0
    Message-Authenticator = 0x00
    Cleartext-Password = "pass.123abcd123"
    Received Access-Accept Id 132 from 127.0.0.1:1812 to 127.0.0.1:47938 length 20
    ```
