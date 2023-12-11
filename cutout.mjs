class CutoutElement extends HTMLElement {
    opos = null;
    clips = null;

    static observedAttributes = ['source', 'fontsize', 'fontfamily', 'linewidth', 'text'];

    constructor() {
        super();
        const shadowRoot = this.attachShadow({mode: 'closed'});

        const document = this.ownerDocument;

        const main = document.createElement('main');
        shadowRoot.append(main);

        const canvas = this.canvas = document.createElement('canvas');
        main.append(canvas);

        this.canvas.addEventListener('pointerdown', e => this.drawhandler(e));
        this.canvas.addEventListener('pointermove', e => this.drawhandler(e));
        this.canvas.addEventListener('pointerup', e => {
            this.opos = null;
            this.preview_frame();
        });

        this.canvas.addEventListener('contextmenu', e => {
            e.preventDefault();
        });

        const finish_button = document.createElement('button');
        finish_button.type = 'button';
        finish_button.textContent = 'Finish';
        main.append(finish_button);

        finish_button.addEventListener('click', () => {
            this.finish();
        })

        const link = document.createElement('link');
        link.setAttribute('rel','stylesheet');
        link.setAttribute('href','cutout_style.css');
        shadowRoot.appendChild(link);

        const svg = this.svg = document.createElementNS('http://www.w3.org/2000/svg','svg');
        main.appendChild(svg);

        const offscreen = this.offscreen = new OffscreenCanvas(canvas.width, canvas.height);

        this.screen_ctx = canvas.getContext('2d');
        this.offscreen_ctx = offscreen.getContext('2d');

        this.lineWidth = 60;
        this.fontSize = 15;
        this.fontFamily = 'serif';
        this.text = 'Ho ho ho!';
    }

    connectedCallback() {
        this.init();
    }

    init() {
        const source = this.getAttribute('source');
        const img = document.createElement('img');
        img.src = source;
        document.body.append(img);

        img.addEventListener('load', () => {

            const {canvas} = this;

            this.source = img;

            const width = this.width = 600;
            const height = this.height = 800;

            this.canvas.width = width;
            this.canvas.height = height;
            this.offscreen.width = width;
            this.offscreen.height = height;

            this.svg.setAttribute('viewBox', `0 0 ${width} ${height}`);

            this.minx = width;
            this.miny = height;
            this.maxx = 0;
            this.maxy = 0;

            const s = this.s = 0.9 * Math.min(width/this.source.width, height/this.source.height);
            this.w = s*this.source.width;
            this.h = s*this.source.height;

            this.drawhandler = (e) => {
                const b = this.canvas.getBoundingClientRect();
                const [x,y] = [e.clientX - b.x, e.clientY - b.y];

                if(e.buttons && this.opos) {
                    this.draw(x, y, e.buttons);
                }

                this.opos = {x,y};
            }

            this.update_preview();

            document.body.removeChild(img);
        });
    }

    preview_frame() {
        if(!this.source) {
            return;
        }
        requestAnimationFrame(() => this.update_preview());
    }

    attributeChangedCallback(name, oldValue, newValue) {
        const method_name = `change_${name}`;
        console.log('change',name, newValue);
        if(this[method_name]) {
            this[method_name](newValue);
        }
        this.preview_frame();
    }

    change_source() {
        this.init();
    
    }

    change_linewidth(value) {
        this.lineWidth = parseFloat(value);
    }

    change_fontsize(value) {
        this.fontSize = parseFloat(value);
    }

    change_fontfamily(value) {
        this.fontFamily = value;
    }

    change_text(value) {
        this.text = value;
    }


    update_preview() {
        const {fontSize, width, height, w, h, minx, miny, maxx, maxy, clip, clips, canvas, screen_ctx, offscreen, offscreen_ctx, lineWidth} = this;

        canvas.width = width;

        //offscreen_ctx.drawImage(this.source, (canvas.width-w)/2, 0, w,h );
        screen_ctx.drawImage(this.source, (canvas.width-w)/2, (canvas.height-h)/2, w,h );
        screen_ctx.globalAlpha = 0.1;
        //screen_ctx.drawImage(offscreen,0,0);
        screen_ctx.globalAlpha = 1;

        //screen_ctx.strokeRect(minx,miny,maxx-minx,maxy-miny);

        const text = this.text.trim() + ' ';

        const text_bits = [];

        const imgd = offscreen_ctx.getImageData(0, 0, width, height).data;
        let x=0;
        let y=0;
        let i = 0;
        const font_family = this.fontFamily;
        screen_ctx.font = `${fontSize}px "${font_family}"`;
        while(y < height) {
            let txt = text[i % text.length];
            let m = screen_ctx.measureText(txt);
            function can_draw_at(x,y) {
                const c = Math.floor((y+m.actualBoundingBoxAscent) * width + x)*4;
                const a = imgd[c+3];
                return x<width && (a == 0 || a===undefined || y>height);
            }
            // find starting point with one character
            while(true) {
                if(can_draw_at(x,y) && can_draw_at(x+m.width,y)) {
                    break;
                }
                if(x + m.width > canvas.width) {
                    x = 0;
                    y += fontSize;
                } else {
                    x += m.width;
                }
            }
            // add characters until occluded or end of line
            let s = 0;
            while(true) {
                s += 1;
                if(s==1000) {
                    throw(new Error("ARG"));
                }
                i += 1;
                txt += text[i % text.length];
                m = screen_ctx.measureText(txt);
                if(!can_draw_at(x+m.width, y)) {
                    txt = txt.slice(0, -1);
                    i -= 1;
                    break;
                }
            }
            m = screen_ctx.measureText(txt);

            // move x to end of drawn text
            screen_ctx.fillText(txt, x, y + fontSize);
            text_bits.push({txt, x, y});
            i += 1;
            x += m.width;
        }

        if(this.opos) {
            screen_ctx.beginPath();    
            const {x,y} = this.opos;
            screen_ctx.moveTo(x+lineWidth/2,y);
            screen_ctx.arc(x,y,lineWidth/2,0,2*Math.PI);
            screen_ctx.stroke();
            screen_ctx.fillStyle = 'hsla(240,100%,100%,0.8)';
            screen_ctx.fill();
        }

        this.svg.innerHTML = '';
        for(let {txt, x, y} of text_bits) {
            const svg_text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            this.svg.appendChild(svg_text);
            svg_text.setAttribute('x', x);
            svg_text.setAttribute('y', y + fontSize);
            svg_text.innerHTML = txt;
            svg_text.setAttribute('font-family', font_family);
            svg_text.setAttribute('font-size', fontSize);
            svg_text.style['white-space'] = 'pre';
        }
    }

    draw(x, y, buttons) {
        const {opos, offscreen_ctx, lineWidth} = this;
        this.minx = Math.min(this.minx, opos.x-lineWidth/2, x-lineWidth/2);
        this.miny = Math.min(this.miny, opos.y-lineWidth/2, y-lineWidth/2);
        this.maxx = Math.max(this.maxx, opos.x+lineWidth/2, x+lineWidth/2);
        this.maxy = Math.max(this.maxy, opos.y+lineWidth/2, y+lineWidth/2);
        offscreen_ctx.globalCompositeOperation = buttons == 2 ? 'destination-out' : 'source-over';
        offscreen_ctx.lineWidth = lineWidth;
        offscreen_ctx.lineCap = 'round';
        offscreen_ctx.beginPath();
        offscreen_ctx.moveTo(opos.x, opos.y);
        offscreen_ctx.lineTo(x,y);
        offscreen_ctx.stroke();

        this.update_preview();
    }

    finish() {
        const svg_content = `<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" viewBox="${this.svg.getAttribute('viewBox')}">${this.svg.innerHTML}</svg>`;
        console.log(svg_content);
        const blob = new Blob([svg_content], {type: 'text/svg+xml'});
        const url = URL.createObjectURL(blob);
        this.dispatchEvent(new CustomEvent('cut-out', {detail: {url, svg_content}}));
    }
}

customElements.define('cut-out', CutoutElement);
