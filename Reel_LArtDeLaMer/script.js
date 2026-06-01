const scenes = [
    { id: 'scene-1', duration: 3000 },
    { id: 'scene-2', duration: 3000 },
    { id: 'scene-3', duration: 2500 },
    { id: 'scene-4', duration: 3000 },
    { id: 'scene-5', duration: 2000 },
    { id: 'scene-6', duration: 3000 }
];

let sceneTimeout;

// Pistes audio
const audioWaves = document.getElementById('audio-waves');
const audioMusic = document.getElementById('audio-music');
const audioSeagulls = document.getElementById('audio-seagulls');
const audioDrops = document.getElementById('audio-drops');

// Génération de particules (Nature)
function createParticles() {
    const container = document.getElementById('particles');
    container.innerHTML = '';
    for (let i = 0; i < 25; i++) {
        let p = document.createElement('div');
        p.classList.add('particle');
        p.style.width = Math.random() * 3 + 1 + 'px';
        p.style.height = p.style.width;
        p.style.left = Math.random() * 100 + '%';
        p.style.top = Math.random() * 100 + '%';
        p.style.animationDuration = (Math.random() * 3 + 3) + 's';
        p.style.animationDelay = Math.random() * 2 + 's';
        container.appendChild(p);
    }
}

document.getElementById('start-btn').addEventListener('click', () => {
    document.getElementById('start-screen').classList.add('hidden');
    document.getElementById('reel-container').classList.remove('hidden');
    
    // Vibe Nature
    createParticles();
    
    // Sons ambiants
    audioWaves.volume = 0.15; // Vagues douces en fond (15%)
    audioMusic.volume = 0.35; // Guitare classique fingerpicking
    
    tryPlay(audioWaves);
    tryPlay(audioMusic);

    playScene(0);
});

function tryPlay(audio) {
    if (audio) {
        audio.currentTime = 0;
        let playPromise = audio.play();
        if (playPromise !== undefined) {
            playPromise.catch(e => console.log("Audio bloqué par le navigateur", e));
        }
    }
}

function playScene(index) {
    if (index >= scenes.length) {
        return; // Fin du Reel
    }

    // Gestion de l'audio spécifique à chaque scène
    if (index === 1) { // Image 2 : Mouettes
        audioSeagulls.volume = 0.08;
        tryPlay(audioSeagulls);
    }
    if (index === 3) { // Image 1 (Caisse) : Gouttes d'eau
        audioDrops.volume = 0.4;
        tryPlay(audioDrops);
    }
    if (index === 4) { // Image 4 (Détail) : Fade out musique
        fadeOutAudio(audioMusic, 2000);
    }

    // Nettoyage de l'état précédent
    document.querySelectorAll('.scene').forEach(scene => {
        scene.classList.remove('active');
    });

    // Activation de la scène actuelle
    const sceneElement = document.getElementById(scenes[index].id);
    sceneElement.classList.add('active');

    // Programmation de la scène suivante (rythme respiratoire exact)
    clearTimeout(sceneTimeout);
    sceneTimeout = setTimeout(() => {
        playScene(index + 1);
    }, scenes[index].duration);
}

function fadeOutAudio(audio, durationMs) {
    const steps = 20;
    const stepTime = durationMs / steps;
    const stepVolume = audio.volume / steps;
    
    let fade = setInterval(() => {
        if (audio.volume > stepVolume) {
            audio.volume -= stepVolume;
        } else {
            audio.volume = 0;
            audio.pause();
            clearInterval(fade);
        }
    }, stepTime);
}
