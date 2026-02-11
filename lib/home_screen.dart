import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _formOpacityAnimation;
  Animation<double>? _logoOffsetY; // Animación para mover el logo
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Duración total de la secuencia
    );

    // El formulario aparece (fade in) un poco después de que el logo empieza a subir
    _formOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn), 
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Esteban aqui calculamos la distancia exacta para que el logo empiece en el CENTRO
      final Size screenSize = MediaQuery.of(context).size;
      const double logoHeight = 350.0; // El tamaño del logo
      const double topSpace = 80.0;    // El SizedBox que pusimos arriba

      // Posición final deseada (Y): topSpace (80.0)
      // Posición inicial deseada (Y): Centro de la pantalla
      final double startY = (screenSize.height - logoHeight) / 2;
      final double endY = topSpace;

      // Cuánto tenemos que bajarlo inicialmente (Offset positivo)
      final double distance = startY - endY;

      _logoOffsetY = Tween<double>(begin: distance, end: 0.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOut), // Sube primero
        ),
      );

      _animationController.forward();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, 
              children: [
                const SizedBox(height: 80), // Espacio superior fijo

                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      // Usamos el valor calculado o 0 si aun no está listo
                      offset: Offset(0, _logoOffsetY?.value ?? 0),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/logo_002.webp',
                    width: 350, 
                    height: 350,
                  ),
                ),

                // Formulario
                // Transformamos para ajustar posición
                Transform.translate(
                  offset: const Offset(0, -60), 
                  child: FadeTransition(
                    opacity: _formOpacityAnimation,
                    child: Column(
                      children: [
                        // Línea divisoria sutil
                        const Divider(
                          color: Colors.grey, 
                          thickness: 0.5, 
                          indent: 60, 
                          endIndent: 60,
                        ),
                        
                        const SizedBox(height: 10), 
                        
                        // Texto "Iniciar Sesión"
                        const Text(
                          "Iniciar Sesión",
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.w500,
                            color: Colors.black, 
                          ),
                        ),

                        const SizedBox(height: 20),
                      
                        // Campo de Email
                        TextField(
                          decoration: InputDecoration(
                            labelText: "Correo Electrónico",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.email, color: Colors.blue),
                            focusedBorder: OutlineInputBorder( 
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Campo de Contraseña
                        TextField(
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Contraseña",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                            focusedBorder: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Botón de Login
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Esteban aqui va ir la lógica de inicio de sesión
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              backgroundColor: Colors.blue, 
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Ingresar",
                              style: TextStyle(
                                fontSize: 18, 
                                color: Colors.white,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      
                        // Enlace de Olvidé mi contraseña
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            "Olvidé mi contraseña",
                            style: TextStyle(
                              color: Colors.blue, 
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
