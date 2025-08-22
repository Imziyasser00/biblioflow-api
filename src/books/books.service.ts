import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateBookDto } from './dto/create-book.dto';
import { UpdateBookDto } from './dto/update-book.dto';

type Book = { id: number; title: string; author?: string };

@Injectable()
export class BooksService {
  private books: Book[] = [];
  private seq = 1;

  create(dto: CreateBookDto) {
    const b: Book = { id: this.seq++, title: dto.title, author: dto.author };
    this.books.push(b);
    return b;
  }
  findAll() { return this.books; }
  findOne(id: number) {
    const b = this.books.find(x => x.id === id);
    if (!b) throw new NotFoundException('Book not found');
    return b;
  }
  update(id: number, dto: UpdateBookDto) {
    const b = this.findOne(id);
    Object.assign(b, dto);
    return b;
  }
  remove(id: number) {
    const i = this.books.findIndex(x => x.id === id);
    if (i === -1) throw new NotFoundException('Book not found');
    return this.books.splice(i, 1)[0];
  }
}
