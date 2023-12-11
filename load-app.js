import show_error from './show-error.mjs';
import './cutout.mjs';
async function init_app() {
    const compilation_error = await show_error;
    if(compilation_error) {
        return;
    }
    const app = Elm.ClippyOuty.init({node: document.body, flags: {}});
}

init_app();
