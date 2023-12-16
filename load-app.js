import show_error from './show-error.mjs';
import './cutout.mjs';
async function init_app() {
    const compilation_error = await show_error;
    if(compilation_error) {
        return;
    }
    const app = Elm.ClippyOuty.init({node: document.body, flags: {}});

    document.body.addEventListener('drop', e => {
        e.preventDefault();
        
        for(let item of e.dataTransfer.items) {
            if(item.kind == 'file') {
                const file = item.getAsFile();
                const url = URL.createObjectURL(file);
                app.ports.imageReceiver.send(url);
            }
        }
    });
}

init_app();
