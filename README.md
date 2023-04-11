# ban_system
- Sistema de prohibición de ingresos de usuarios al servidor


# DESCRIPCIÓN
Un sistema de prohibición que interactúa con una base de datos, tiene la posibilidad de agregar IP's, SteamID's y HID's por un tiempo establecido en minutos, prohibiendo al usuario y facilitando así la exclusión del mismo.

# CAMBIOS

- Optimización del código
- Reducción de tablas
- Ahora se puede ver la información del usuario baneado en la lista de ban.
- Corregido algunos errores.
- Ahora se crea un log por cada acción realizada: ban, unban, etc...

# COMANDOS

- say /.!ban: Abre el menú de ban
- amx_ban_add_ip: "IP" "MINUTOS" "RAZÓN": Agrega una IP a la base de datos.
- amx_ban_add_steamid: "STEAMID" "MINUTOS" "RAZÓN": Agrega un STEAMID a la base de datos.
- amx_ban_add_hid: "HID" "MINUTOS" "RAZÓN": Agrega una HID a la base de datos.
- amx_ban_system_update_frequency 60.0: Tiempo en el que actualiza la lista de ban, para verificar el tiempo.

# CARACTERÍSTICAS DEL MENÚ PRINCIPAL

- Expulsar usuarios: Expulsar a un usuario del servidor
- Banear usuarios: Banea a un usuario del servidor: El ban puede ser por (IP / STEAMID / HWIWD [sXe necesario]).
- Banear IP: Agrega una IP a la base de datos.
- Banear STEAMID: Agrega un STEAMID a la base de datos.
- Lista de usuarios baneados con su descripción del ban:
- Lista de ban: Permite ver los usuarios baneados, así mismo el NOMBRE DE USUARIO, IP, STEAMID y HID de los últimos diez que se desconectaron.

# CARACTERÍSTICAS DEL MENÚ DE BAN

- Calcular días en minutos: Permite calcular los minutos que equivalen a * días.
- Calcular horas en minutos: Permite calcular los minutos que equivalen a * horas.
- Introducir minutos: Introduce los minutos del ban.
- Introducir razón: Introduce la razón del ban.
- Minutos en total: Calcula los minutos introducidos de los días y las horas.
- Tipo de ban: Introduce el tipo de ban (IP / STEAMID / HID).
- Ejecutar el ban: Ejecuta el ban al usuario.

![ban](https://user-images.githubusercontent.com/94066331/231139528-03dfee5f-c6e6-45c4-9796-d7a376e1f49b.png)
![ban2](https://user-images.githubusercontent.com/94066331/231139668-cae4a48b-eb06-4d01-b745-debfe8662054.png)


- https://amxmodx-es.com/Thread-Sistema-de-ban-SQLite3-Actualizaci%C3%B3n-17-02-2019
