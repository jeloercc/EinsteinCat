/*
 TouchBarPrivate.h
 EinsteinCat

 Declaraciones de métodos PRIVADOS (no documentados) de AppKit para la Touch Bar.
 Basado en las declaraciones de MTMR (github.com/Toxblh/MTMR, MTMR/CBridge/TouchBarPrivateApi.h).

 Este header solo le dice a Swift que estos métodos existen. No enlaza nada:
 los métodos de Objective-C se buscan en tiempo de ejecución al llamarlos.
 Si Apple los quita en otra versión de macOS, la llamada fallará.
*/

#import <AppKit/AppKit.h>
#import <libproc.h>

@interface NSTouchBarItem (EinsteinCatPrivate)

// Agrega / quita un ítem de la "tira de control" (la parte derecha de la Touch Bar).
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem *)item;

@end

@interface NSTouchBar (EinsteinCatPrivate)

+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                         placement:(long long)placement
           systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
           systemTrayItemIdentifier:(NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)minimizeSystemModalTouchBar:(NSTouchBar *)touchBar;

@end
