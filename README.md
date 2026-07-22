# ⚽ PCFútbol [https://salinasdev.github.io/pcfutbol/pcfutbol.html]

> **Un juego de gestión de fútbol español, desarrollado con Godot 4**  
> Inspirado en el clásico PC Fútbol — gestiona tu equipo, gana la Liga y escribe la historia.

---

## 🎮 Descripción

**PCFútbol** te pone en la piel del míster. Elige tu equipo de **La Liga española**, ficha jugadores, diseña tu táctica y guía a tu escuadra a lo largo de una temporada completa de **38 jornadas**. Cada decisión importa: la alineación, el presupuesto, el estadio... y la prensa siempre está mirando.

Optimizado para **móvil en vertical (720×1280)** con interfaz táctil y navegación fluida.

---

## ✨ Características principales

### 🏆 Liga española completa
- Los **20 equipos reales** de La Liga (Real Madrid, FC Barcelona, Atlético de Madrid y más)
- Calendario completo de **38 jornadas** — ida y vuelta
- Clasificación en tiempo real con zonas de campeón, descenso y europeas

### ⚙️ Motor de partidos
- **Minuto a minuto** con narración de eventos para los partidos del jugador
- Simulación rápida para los partidos de la IA (modelo xG + distribución de Poisson)
- Ventaja de campo, tarjetas, lesiones y disciplina en tiempo real

### 👥 Gestión del equipo
- **11 titulares + 5 suplentes** con sistema de arrastrar y soltar
- Energía individual: los jugadores se cansan y se recuperan semana a semana
- **Sistema de tarjetas:** 5 amarillas = sanción, roja directa = partido fuera
- Lesiones con duración real (1-4 semanas)

### 💰 Finanzas y fichajes
- Presupuesto de transferencias y masa salarial independientes
- Mercado de fichajes con valoraciones dinámicas por edad y rendimiento
- Ingresos de taquilla basados en reputación, precio de entradas e instalaciones

### 🏟️ Estadio
- Mejora graderías (hasta +22.000 aforo por zona)
- Parking, marcador, iluminación, tienda, cafetería y más
- La asistencia varía según el estado del equipo y las instalaciones

### 📰 Prensa y noticias
- Feed de noticias dinámico generado cada semana
- Categorías: Resultados, Fichajes, Entrevistas, Rumores, Vestuario, Clasificación
- Declaraciones de jugadores según el rendimiento

### 💾 Guardado completo
- Estado de la partida serializado a JSON (`user://savegame.json`)
- Todos los datos persistentes: jugadores, equipos, finanzas, clasificación y noticias

---

## 🗂️ Estructura del proyecto

```
pcfutbol/
├── scripts/
│   ├── data/
│   │   ├── player.gd          # Clase jugador (atributos, contratos, estado)
│   │   ├── team.gd            # Clase equipo (plantilla, finanzas, estadio)
│   │   ├── league.gd          # Clase liga (calendario, resultados)
│   │   └── data_generator.gd  # Genera los 20 equipos de La Liga con datos reales
│   ├── managers/
│   │   ├── game_manager.gd    # Núcleo central: fechas, temporada, señales
│   │   ├── league_manager.gd  # Clasificación, sanciones, fixtures
│   │   ├── transfer_manager.gd# Mercado de fichajes y valoraciones
│   │   ├── news_manager.gd    # Generación de noticias semanales
│   │   └── save_manager.gd    # Guardado y carga de partida
│   └── simulation/
│       ├── match_engine.gd    # Motor minuto a minuto (partidos jugador)
│       └── match_simulator.gd # Simulador rápido (partidos IA)
├── scenes/
│   ├── main_menu/             # Menú principal y configuración de nueva partida
│   └── game/
│       ├── office/            # Hub principal: próximo partido, navegación
│       ├── squad/             # Editor de alineación y plantilla
│       ├── match/             # Vista de partido (eventos en directo)
│       ├── calendar/          # Calendario de jornadas
│       ├── standings/         # Clasificación de liga
│       ├── transfers/         # Mercado de jugadores
│       ├── press/             # Sala de prensa y noticias
│       ├── tactics/           # Editor de tácticas y formación
│       ├── stadium/           # Gestión y mejoras del estadio
│       ├── rival/             # Ficha del rival
│       └── season_end/        # Pantalla de fin de temporada
└── assets/
    ├── teams/                 # Escudos de los 20 equipos
    └── stadiums/              # Fotos de los estadios
```

---

## 🔧 Requisitos

| Componente | Versión |
|---|---|
| [Godot Engine](https://godotengine.org/) | **4.7+** |
| Plataforma objetivo | Android / Web / Windows |
| Orientación | Vertical (720×1280) |

---

## 🚀 Cómo empezar

1. **Clona** el repositorio o descarga el proyecto.
2. **Abre** Godot 4.7+ e importa la carpeta del proyecto.
3. **Ejecuta** la escena principal `pcfutbol.html` o pulsa F5 en el editor.
4. Elige tu equipo, ponle nombre a tu mánager y... ¡a ganar La Liga!

---

## ☁️ Probar cambios sin Godot local

Si no puedes ejecutar Godot en tu equipo, puedes seguir este flujo:

1. Edita código y assets en local.
2. Haz `git push` a `main` o `master`.
3. GitHub Actions ejecuta export Web con Godot 4.7 en remoto.
4. El resultado se publica automáticamente en GitHub Pages.

Notas:

- En `pull_request` también se compila, pero solo sube artefacto para validación (no publica).
- Si aún no lo hiciste, en GitHub ve a **Settings > Pages** y selecciona **Build and deployment: GitHub Actions**.
- URL esperada de publicación: `https://<usuario>.github.io/<repo>/`.

---

## 📊 Equipos disponibles

| Reputación | Equipo | Estadio | Aforo |
|:---:|---|---|---:|
| 90 | Real Madrid | Estadio Santiago Bernabéu | 80.000 |
| 88 | FC Barcelona | Estadi Olímpic Lluís Companys | 90.000 |
| 82 | Atlético de Madrid | Cívitas Metropolitano | 67.000 |
| 78 | Real Sociedad | Reale Arena | 40.000 |
| 75 | Athletic Club | San Mamés | 53.000 |
| 72 | Sevilla FC | Estadio Ramón Sánchez-Pizjuán | 43.000 |
| ... | *y 14 equipos más* | | |

---

## ⚡ Sistemas de juego

### Valoración de jugadores
$$\text{Valor} = \text{overall}^2 \times \text{factor\_edad} \times 200$$

- Factor edad **1.64** para sub-21 (prima de joven promesa)
- Factor edad **0.2** para mayores de 35 (devaluación por edad)

### Rendimiento efectivo
$$\text{Overall efectivo} = \text{overall\_base} \times \left(0.6 + 0.4 \times \frac{\text{energía}}{100}\right)$$

### Asistencia al estadio
Calculada dinámicamente en función de reputación del equipo, precio de entrada, instalaciones (aparcamiento, marcador, aseos) y momento de la temporada.

---

## 🤝 Contribuir

¿Quieres añadir algo? Pull requests bienvenidos. Algunas ideas en el backlog:

- [ ] Ascensos y descensos reales entre ligas
- [ ] Competición de Copa
- [ ] Editor de tácticas completo
- [ ] Estadísticas históricas de temporadas anteriores
- [ ] Modo multijugador local (2 mánagers)

---

## 📄 Licencia

Proyecto personal de desarrollo independiente. Assets de equipos y estadios son de uso educativo/demostrativo.

---

<p align="center">
  <em>Hecho con ❤️ y mucho fútbol · Godot 4 · GDScript</em>
</p>
