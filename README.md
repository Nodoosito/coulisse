# Coulisse

Coulisse range les icônes de la barre des menus de macOS : ce qui ne sert pas passe en coulisse, et revient d'un clic.

> **Basé sur [Hidden Bar](https://github.com/consolelabs/hidden)** de Dwarves Foundation et Console Labs, sous licence MIT.
> Coulisse est un fork indépendant : il n'est ni affilié à Console Labs ni soutenu par eux.
> Le README original de Hidden Bar est conservé dans [`docs/README-HiddenBar.md`](docs/README-HiddenBar.md).

## Ce que Coulisse ajoute à Hidden Bar

- **Fenêtre des icônes** : quand la barre est pleine (encoche, petit écran), un clic sur la flèche ouvre les icônes masquées dans une petite fenêtre. Tapez pour filtrer, ⌘1–⌘9 pour ouvrir.
- **Profils** : plusieurs dispositions d'icônes, qui changent seules selon l'écran branché ou l'alimentation (batterie, secteur).
- **Règles par app** : afficher une icône masquée seulement quand une app précise est au premier plan.
- **Masquage automatique plus fin** : délais de 2 s à 5 min, décompte à partir du moment où la souris quitte la barre, repli quand on change d'app.
- **Écrans** : tout afficher quand un écran externe est branché, ou quand le Mac est fermé sur un écran externe.
- **Apparence de la barre** : espacement des icônes (réglage de macOS) et teinte derrière la barre.
- **Recherche** : la palette trouve aussi les icônes visibles ; ⌘1–⌘9 ouvrent un résultat.
- **Fichier de réglages** : exporter et importer réglages, profils et règles.

## Installation

1. Téléchargez le `.zip` de la dernière version dans les Releases GitHub, puis glissez `Coulisse.app` dans **Applications**.
2. Coulisse n'est pas notarisé par Apple. Au premier lancement, macOS le bloque : ouvrez
   **Réglages Système → Confidentialité et sécurité** et cliquez sur **Ouvrir quand même**.
3. Accordez l'accès **Accessibilité** quand Coulisse le demande (obligatoire sur macOS 27).
4. Quittez Hidden Bar s'il tourne encore : deux gestionnaires de barre des menus en même temps se gênent.

## Compiler soi-même

Xcode 27 ou plus récent, macOS 13 minimum.

```sh
xcodebuild -project 'Hidden Bar.xcodeproj' -scheme 'Hidden Bar' -configuration Release-Direct build
```

Pour signer avec votre propre compte, remplacez `DEVELOPMENT_TEAM` dans le projet par votre identifiant d'équipe Apple.

## Licence

MIT. Voir [`LICENSE`](LICENSE) : les copyrights de Dwarves Foundation et de Console Labs y sont conservés.
